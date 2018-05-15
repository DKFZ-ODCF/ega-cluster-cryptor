#!/bin/bash

# INFO: if you want to restart the encryption for a file, delete all the corresponding *.md5 and *.gpg files
#
# This script will automatically find the most-recent "filelist*.txt" file and process files therein.
# If you wish to use a different filelist, you can specify this as a command line argument:
#   1-submit-encryption-jobs.sh your-filelist.txt

# Check if required EGA public key is known.
gpg --list-keys EGA_Public_key >/dev/null 2>&1;
if [ $? != 0 ]; then
  echo "EGA public key not present in GPG key-ring. Cannot encrypt."
  echo "  please install it using \`gpg --import EGA_public_key.gpg\`"
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

    # for smaller files: request less walltime so we get into the "fast" or "medium" queue
    # (faster processing!)
    # limits were experimentally established on 2017-09-04, using pbs3/4 cluster
    # results: very linear speed of ~5G/7minutes
    # The below limits keep some margin.
    FAST_LIMIT="10737418240"   # 10 x (1024^3) = 10G ~  14 minutes, queue limit  20 min.
    MEDIUM_LIMIT="85899345920" # 80 x (1024^3) = 80G ~ 112 minutes, queue limit 120 min.
    FILESIZE=$(stat -c '%s' "$(readlink -f "$FULL_FILE")")
    if [ "$FILESIZE" -le $FAST_LIMIT ]; then
      REQ_WALLTIME="00:19:59"
    elif [ "$FILESIZE" -le $MEDIUM_LIMIT ]; then
      REQ_WALLTIME="01:59:59"
    else
      REQ_WALLTIME="11:59:59"
    fi

    # prepend filename before qsub job-id output (intentionally no newline!)
    printf "%-29s\t" "$SHORTNAME" | tee -a "$SUBMITLOG"
    # actual job submission, prints job-id
    qsub \
        -v FULL_FILE="$FULL_FILE",WORKDIR="$WORKDIR" \
        -N "ega-encryption-$SHORTNAME" \
        -e "$JOBLOGDIR" \
        -o "$JOBLOGDIR" \
        -l "walltime=$REQ_WALLTIME" \
        "${BASH_SOURCE%/*}/PBSJOB-ega-encryption.sh" | tee -a "$SUBMITLOG"
  fi
done
