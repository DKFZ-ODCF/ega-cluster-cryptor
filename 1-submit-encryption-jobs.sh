#!/bin/bash

# INFO: if you want to restart the encryption for a file, delete all the corresponding *.md5 and *.gpg files
#
# This script will automatically find the most-recent "filelist*.txt" file and process files therein.
# If you wish to use a different filelist, you can specify this as a command line argument:
#   1-submit-encryption-jobs.sh your-filelist.txt

# Check if required EGA public key is known.
gpg --list-keys EGA_Public_key >/dev/null 2>&1;
if [ $? != 0 ]; then
  >&2 echo "EGA public key not present in GPG key-ring. Cannot encrypt."
  >&2 echo "  please install it using \`gpg --import EGA_public_key.gpg\`"
fi

# find wherever this script is, and load the util library next to it
source "$(dirname $BASH_SOURCE)/util.sh"

# Get default, latest input file, OR whatever the user wants
OVERRIDE_FILE="$1"
FILE_LIST=$(get_default_or_override_filelist "$OVERRIDE_FILE");
verify_filelist "$FILE_LIST"

echo "using file-list: $FILE_LIST"


WORKDIR="$(pwd)/files/"
SUBMITLOG="$(pwd)/_submitted_jobs_"$(date +%Y-%m-%d_%H:%M:%S)
JOBLOGDIR="$(pwd)/cluster-logs"
if [ ! -d "$JOBLOGDIR" ]; then
  mkdir "$JOBLOGDIR"
fi


# Get files from file_list that DON'T have a corresponding .gpg file
# TODO: when adapting FILE_LIST to have non-absolute paths, also adapt this spot
unencryptedFiles=$(\
  comm -23 \
   <(sort "$FILE_LIST") \
   <( \
      find "$WORKDIR" -type f \( -name "*.gpg" -or -name "*.gpg.partial" \) \
      | sed -E "s/\.gpg(.partial)?//g" \
      | sort \
    ) \
)


for FULL_FILE in $unencryptedFiles; do
  if [ ! -e "$FULL_FILE" ]; then
    echo "WARNING: File not found: $FULL_FILE" | tee -a "$SUBMITLOG"
  else
    # readable label, without the full absolute path
    SHORTNAME=$(basename "$FULL_FILE")

    # Request a sensible amount of walltime, and let the queue runlimits sort out which queue we get
    FILESIZE=$(stat -c '%s' "$(readlink -f "$FULL_FILE")") # in bytes
    # a rough estimate of encryption speed is 5GB/7 minutes ~ 0.7GB/min ~ 13 MB/s (established experimentally on our infrastructure)
    # you might want to change this, as it is fairly conservative
    BYTES_PER_MINUTE=750000000

    MINUTES="$(( FILESIZE / BYTES_PER_MINUTE ))"
    HOURS="$(( MINUTES / 60 ))"
    MINUTES="$(( MINUTES - ( 60 * HOURS ) + 1 ))" # +1 to avoid requesting "0" for tiny files, and as margin

    # PBS wants [hours:]minutes:seconds
    REQ_WALLTIME=$( printf '%2d:%20d:00' $HOURS $MINUTES )


    # prepend filename before qsub job-id output (intentionally no newline!)
    printf "%-29s\t%s\t" "$SHORTNAME" "$REQ_WALLTIME" | tee -a "$SUBMITLOG"
    # actual job submission, prints job-id
    qsub \
        -v FULL_FILE="$FULL_FILE",WORKDIR="$WORKDIR" \
        -N "egacrypt-$SHORTNAME" \
        -e "$JOBLOGDIR" \
        -o "$JOBLOGDIR" \
        -l "walltime=$REQ_WALLTIME" \
        < "${BASH_SOURCE%/*}/PBSJOB-ega-encryption.sh" | tee -a "$SUBMITLOG"
  fi
done
