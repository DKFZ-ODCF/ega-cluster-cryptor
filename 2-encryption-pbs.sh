#!/bin/bash

# INFO: if you want to restart the encryption for a file, delete all the corresponding *.md5 and *.gpg files
#
# This script will automatically find the most-recent "fileList*.txt" file and process files therein.
# If you wish to use a different fileList, you can specify this as a command line argument:
#   2-encryption-pbs.sh your-fileList.txt


source ./util.sh;

# meaningful name for first argument
OVERRIDE_FILE="$1"
FILE_LIST=$(get_default_or_override_fileList "$OVERRIDE_FILE");
verify_fileList "$FILE_LIST"

unencryptedFiles=$(\
  comm -23 \
   <(cat "$FILE_LIST" | sort) \
   <(find `pwd` -type f -name "*.gpg" | sed "s/\.gpg//g" | sort)
)

WORKDIR=$(pwd)
for FULL_FILE in $unencryptedFiles
do
   qsub -v FULL_FILE=$FULL_FILE,WORKDIR=$WORKDIR ega-encryption.sh
done
