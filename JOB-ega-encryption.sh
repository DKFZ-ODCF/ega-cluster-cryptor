#!/bin/bash

# Job Name - can be set more-specific from qsub command
#PBS  -N egacrypt
#BSUB -J egacrypt
# cpu time, when not overriden by submitter
# memory is very generous, 98% of jobs consistently use 10.5 +- 0,2 MB of memory,
#   but the remaining outliers jump to ~120MB; no idea why...
#PBS -l walltime=08:00:00,mem=200MB
#BSUB -W 08:00
#BSUB -M 200MB
# request 1 node
#PBS  -l nodes=1
#BSUB -n 1

set -u

cd "$WORKDIR"

gpg --list-keys EGA_Public_key >/dev/null 2>&1;
if [ $? != 0 ]; then
  >&2 echo "EGA public key not present in GPG keyring on this worker node
  -> Cluster node cannot encrypt.

Please obtain the key from EGA: https://ega-archive.org/submission/EGA_public_key .
Then contact your cluster administrator on how to deploy GPG-keys to worker nodes"
  exit 17
fi

# extract filename from full path
FILE=$(basename "$FULL_FILE")
ENCRYPTED_PARTIAL="$FILE.gpg.partial"
ENCRYPTED_MD5_PARTIAL="$FILE.gpg.md5.partial"
PLAIN_MD5_PARTIAL="$FILE.md5.partial"

# double-check we're not accidentally encrypting this file already
#   since output filenames are non-randomly derived from the input filename,
#   two concurrent encryption jobs will trash the output
# Abort if we're the second one
if [ -e "$ENCRYPTED_PARTIAL" -o -e "$ENCRYPTED_MD5_PARTIAL" -o -e "$PLAIN_MD5_PARTIAL" ]; then
  >&2 echo "ABORT: partial files already present, encryption probably already running."
  >&2 ls -alh "$ENCRYPTED_PARTIAL" "$ENCRYPTED_MD5_PARTIAL" "$PLAIN_MD5_PARTIAL"
  exit 2
fi


# Process the file! This is a bit tricky:
#  - We use piping and tee-ing extensively to ensure each disk-IO is only needed once
#    and we can calculate the md5 checksums while we have it in memory "anyway".
#  - the recursive tee-ing means we have two levels of PIPESTATUS to worry about.
#  - the inner subshell (from `>()` process substitution) cannot export variables to the parent, so writes a tempfile
#  - GPG Key A6F53234DBB82C79 = EGA_Public_key, imported from https://ega-archive.org/submission/EGA_public_key
#    the "long key ID" is the last 16 characters/64 bytes from the key fingerprint (spaces removed)
#  - Put all results into .partial files first, to signal that they are incomplete
INNER_PIPESTATUS=$(mktemp --tmpdir="$WORKDIR" --suffix="-pipestatus-inner.tmp")
tee < "$FILE" >(
    gpg --encrypt --trusted-key 'A6F53234DBB82C79' --recipient EGA_Public_key | tee \
        "$ENCRYPTED_PARTIAL" \
        | md5sum > "$ENCRYPTED_MD5_PARTIAL"; \
    echo "INNER ${PIPESTATUS[*]}" > "$INNER_PIPESTATUS" \
  ) \
  | md5sum > "$PLAIN_MD5_PARTIAL"; \
  OUTER_PIPESTATUS="OUTER ${PIPESTATUS[*]}"
TOTAL_PIPESTATUS="$(cat "$INNER_PIPESTATUS") - ${OUTER_PIPESTATUS}  $FILE"
rm "$INNER_PIPESTATUS"

# replace '-' label (STDIN) in md5 files with the actual file-name used
# to comply with the commonly accepted md5sum fileformat
sed -i s/-/"$FILE.gpg"/ "$ENCRYPTED_MD5_PARTIAL"
sed -i s/-/"$FILE"/     "$PLAIN_MD5_PARTIAL"

# we're done. Check if everything worked without problems
if [ "$TOTAL_PIPESTATUS" == "INNER 0 0 0 - OUTER 0 0  $FILE" ]; then
  # success! no pipes broke :-D
  STATUS_EXTENSION='' # blank means "success"
  EXIT_STATUS=0
else
  # failure! at least one pipe broke :-(
  >&2 echo "ERROR: at least one pipe broke; pipe output: $TOTAL_PIPESTATUS"
  STATUS_EXTENSION=".failed"
  EXIT_STATUS=1 # signal non-success to job system
fi

# give read-access to the entire project-group
# (useful when encrypting is done by a different user than the upload)
chmod g+r "$ENCRYPTED_PARTIAL" "$ENCRYPTED_MD5_PARTIAL" "$PLAIN_MD5_PARTIAL"

# move generated files to final location, depending on success-or-not
mv "$ENCRYPTED_PARTIAL"       "$FILE.gpg$STATUS_EXTENSION"
mv "$ENCRYPTED_MD5_PARTIAL"   "$FILE.gpg.md5$STATUS_EXTENSION"
mv "$PLAIN_MD5_PARTIAL"       "$FILE.md5$STATUS_EXTENSION"

# let job managment system know if we succeeded (or not)
exit $EXIT_STATUS
