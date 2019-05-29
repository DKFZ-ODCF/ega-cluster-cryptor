#!/bin/bash

# INFO: if you want to restart the encryption for a file, delete all the corresponding *.md5 and *.gpg files
#
# This script will automatically find the most-recent "to-encrypt*.txt" file and process files therein.
# If you wish to use a different to-encrypt list, you can specify this as a command line argument:
#   1-submit-encryption-jobs.sh your-filelist.txt

# Check if required EGA public key is known.
gpg --list-keys EGA_Public_key >/dev/null 2>&1;
if [ $? != 0 ]; then
  >&2 echo "EGA public key not present in GPG keyring on this submission host
  -> Cluster nodes probably cannot encrypt.

Please obtain the key from EGA: https://ega-archive.org/submission/EGA_public_key
  Install the obtained key with: \`gpg --import EGA_public_key.gpg\`
  There is a copy included with this script, but are you REALLY sure that is the right one? >:-)"
fi

CLUSTER_SYSTEM='LSF'
#CLUSTER_SYSTEM='PBS'

echo "using cluster system: $CLUSTER_SYSTEM"


# find wherever this script is, and load the util library next to it
source "$(dirname "$BASH_SOURCE")/util.sh"

# Get default, latest input file, OR whatever the user wants
OVERRIDE_FILE="$1"
TO_ENCRYPT_LIST=$(get_default_or_override_to_encrypt_list "$OVERRIDE_FILE");
verify_to_encrypt_list "$TO_ENCRYPT_LIST"

echo "using file-list: $TO_ENCRYPT_LIST"


WORKDIR="$(pwd)/files/"
SUBMITLOG="$(pwd)/_submitted_jobs_"$(date +%Y-%m-%d_%H:%M:%S)
JOBLOGDIR="$(pwd)/cluster-logs"
if [ ! -d "$JOBLOGDIR" ]; then
  mkdir "$JOBLOGDIR"
fi


# Get files from to-encrypt list that DON'T have a corresponding .gpg file
# first input is the to-encrypt filelist, using `sed` to normalise for either absolute paths or relative paths in WORKDIR
# second input is the contents of WORKDIR: all finished or partial encryption output, massaged with `sed` to match the original filename.
comm_output=$(\
  comm \
   <( cut -f2 "$TO_ENCRYPT_LIST" \
      | sed -E -e 's#^.+/##' \
      | sort \
    ) \
   <( \
      find "$WORKDIR" -type f \( -name '*.gpg' -or -name '*.gpg.partial' \) \
      | sed -E -e 's#^.+/##' -e 's/\.gpg(.partial)?$//' \
      | sort \
    ) \
)
unencryptedFiles=( $( cut -f1 <<<"$comm_output" ) )
alreadyEncryptedFiles=( $( cut -f3 <<<"$comm_output" ) )
echo "found ${#alreadyEncryptedFiles[*]} encrypted and/or in-progress files. Submitting ${#unencryptedFiles[*]} new encryption jobs:"

if [ ${#unencryptedFiles[*]} -ge 1 ]; then
  echo -e "FILE                        \tWTIME\tSUBMISSION_FEEDBACK" | tee -a "$SUBMITLOG"
fi
for SHORTNAME in ${unencryptedFiles[*]}; do
  FULL_FILE="$WORKDIR/$SHORTNAME"
  if [ ! -e "$FULL_FILE" ]; then
    echo "WARNING: File not found: $FULL_FILE" | tee -a "$SUBMITLOG"
  else
    # Request a sensible amount of walltime, and let the queue runlimits sort out which queue we get
    FILESIZE=$(stat -c '%s' "$(readlink -f "$FULL_FILE")") # in bytes
    # a rough estimate of encryption speed is 5GB/7 minutes ~ 0.7GB/min ~ 13 MB/s (established experimentally on our infrastructure)
    # you might want to change this, as it is fairly conservative
    BYTES_PER_MINUTE=750000000

    MINUTES="$(( FILESIZE / BYTES_PER_MINUTE ))"
    HOURS="$(( MINUTES / 60 ))"
    MINUTES="$(( MINUTES - ( 60 * HOURS ) + 1 ))" # +1 to avoid requesting "0" for tiny files, and as margin

    # prepend filename before job-id output (intentionally no newline!)
    printf "%-29s\t%dh%02dm\t" "$SHORTNAME" "$HOURS" "$MINUTES" | tee -a "$SUBMITLOG"

    # actual job submission, prints job-id
    if [ $CLUSTER_SYSTEM == "PBS" ]; then
      qsub \
          -v "FULL_FILE=$FULL_FILE,WORKDIR=$WORKDIR" \
          -N "egacrypt-$SHORTNAME" \
          -e "$JOBLOGDIR" \
          -o "$JOBLOGDIR" \
          -l "walltime=$( printf '%2d:%20d:00' $HOURS $MINUTES )" \
          < "${BASH_SOURCE%/*}/JOB-ega-encryption.sh" | tee -a "$SUBMITLOG"
    elif [ $CLUSTER_SYSTEM == "LSF" ]; then
      bsub \
          -env "FULL_FILE=$FULL_FILE, WORKDIR=$WORKDIR" \
          -J "egacrypt-$SHORTNAME" \
          -Jd "encrypting $SHORTNAME ($FULL_FILE) for the EGA archive" \
          -e "$JOBLOGDIR/%J-$SHORTNAME.err" \
          -o "$JOBLOGDIR/%J-$SHORTNAME.out" \
          -W "$( printf '%2d:%02d' $HOURS $MINUTES )" \
          < "${BASH_SOURCE%/*}/JOB-ega-encryption.sh" | tee -a "$SUBMITLOG"
    else
      echo "ERROR: specified unknown cluster system '$CLUSTER_SYSTEM'; no jobs submitted" | tee -a "$SUBMITLOG"
      exit 42
    fi
  fi
done
