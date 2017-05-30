#!/bin/bash

# INFO: if you want to restart the encryption for a file, delete all the corresponding *.md5 and *.gpg files
#
# This script will automatically find the most-recent "fileList*.txt" file and process files therein.
# If you wish to use a different fileList, you can specify this as a command line argument:
#   2-encryption-pbs.sh your-fileList.txt

# find wherever this script is, and load the util library next to it
source ${BASH_SOURCE%/*}/util.sh

# Get default, latest input file, OR whatever the user wants
OVERRIDE_FILE="$1"
FILE_LIST=$(get_default_or_override_fileList "$OVERRIDE_FILE");
verify_fileList "$FILE_LIST"

echo "using file-list: $FILE_LIST"

# Get files from file_list that DON'T have a corresponding .gpg file
unencryptedFiles=$(\
  comm -23 \
   <(cat "$FILE_LIST" | sort) \
   <(find $(pwd) -type f -name "*.gpg" | sed "s/\.gpg//g" | sort) \
)

WORKDIR=$(pwd)
for FULL_FILE in $unencryptedFiles
do
    # prepend filename before qsub job-id output (intentionally no newline!)
    printf "%-29s " $FULL_FILE
    qsub -v FULL_FILE=$FULL_FILE,WORKDIR=$WORKDIR ${BASH_SOURCE%/*}/ega-encryption.sh
done
