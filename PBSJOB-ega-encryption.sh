#!/bin/bash

# Job Name - can be set more-specific from qsub command
#PBS -N ega-encryption.sh
# cpu time, when not overriden by submitter
# memory is very generous, 98% of jobs consistently use 10.5 +- 0,2 MB of memory,
#   but the remaining outliers jump to ~120MB; no idea why...
#PBS -l walltime=08:00:00,mem=200MB
# request 1 node
#PBS -l nodes=1
#PBS -A io_throttle

cd "$WORKDIR"

# extract filename from full path
FILE=$(basename "$FULL_FILE")
ENCRYPTED_PARTIAL="$FILE.gpg.partial"
ENCRYPTED_MD5_PARTIAL="$FILE.gpg.md5.partial"
PLAIN_MD5_PARTIAL="$FILE.md5.partial"

# double-check we're not accidentally encrypting this file already
#   since output filenames are based on input filename, two concurrent
#   encryption jobs will trash the output
# Abort if we're the second one
if [ -e "$ENCRYPTED_PARTIAL" -o -e "$ENCRYPTED_MD5_PARTIAL" -o -e "$PLAIN_MD5_PARTIAL" ]; then
  >&2 echo "ABORT: partial files already present, encryption probably already running."
  >&2 ls -alh "$ENCRYPTED_PARTIAL" "$ENCRYPTED_MD5_PARTIAL" "$PLAIN_MD5_PARTIAL"
  exit 2
fi

# set temp files
INTERNAL=$(mktemp --suffix="-encryption-pipestatus-internal")
EXTERNAL=$(mktemp --suffix="-encryption-pipestatus-external")
TOTAL_PIPESTATUS="$FILE.pipestatus"

# process file
#  Put all results into .partial files first, to signal that they are incomplete
#  We use piping and tee-ing extensively to ensure each disk-IO is only needed once
#  and we can calculate the md5 checksums while we have it in memory "anyway".
tee < "$FILE" >(
    gpg -e --always-trust -r EGA_Public_key | tee \
        "$ENCRYPTED_PARTIAL" \
        | md5sum > "$ENCRYPTED_MD5_PARTIAL"; \
    echo "INTERNAL ${PIPESTATUS[*]}" > "$INTERNAL" \
  ) \
  | md5sum > "$PLAIN_MD5_PARTIAL"; \
  echo "EXTERNAL ${PIPESTATUS[*]}" > "$EXTERNAL"
# store combined pipestatus into a file, delete intermediate tempfiles
echo "$(cat "$INTERNAL")  $(cat "$EXTERNAL")  $FILE" > "$TOTAL_PIPESTATUS"
rm "$INTERNAL" "$EXTERNAL"

# replace '-' label (STDIN) in md5 files with the actual file-name used
# to comply with the commonly accepted md5sum fileformat
sed -i s/-/"$FILE.gpg"/ "$ENCRYPTED_MD5_PARTIAL"
sed -i s/-/"$FILE"/     "$PLAIN_MD5_PARTIAL"

# we're done. Check if everything worked without problems, and
# rename our .partial files accordingly
if [ "$(cat "$TOTAL_PIPESTATUS")" == "INTERNAL 0 0 0  EXTERNAL 0 0  $FILE" ]; then
  # success! no pipes broke :-D
  mv "$ENCRYPTED_PARTIAL"       "$FILE.gpg"
  mv "$ENCRYPTED_MD5_PARTIAL"   "$FILE.gpg.md5"
  mv "$PLAIN_MD5_PARTIAL"       "$FILE.md5"
  rm "$TOTAL_PIPESTATUS" # not needed if everything worked :-)
else
  # failure! at least one pipe broke :-(
  mv "$ENCRYPTED_PARTIAL"       "$FILE.gpg.failed"
  mv "$ENCRYPTED_MD5_PARTIAL"   "$FILE.gpg.md5.failed"
  mv "$PLAIN_MD5_PARTIAL"       "$FILE.md5.failed"
  # leave $TOTAL_PIPESTATUS around, in case people wish to debug.
  exit 1 # signal non-success to PBS
fi
