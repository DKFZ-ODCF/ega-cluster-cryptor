#!/bin/bash

export ASPERA_SCP_PASS="TODO";
export ASPERA_DESTINATION="ega-box-TODO@fasp.ega.ebi.ac.uk:/."

OVERRIDE_FILE="$1"
FILE_LIST=$(get_default_or_override_fileList "$OVERRIDE_FILE");
verify_fileList "$FILE_LIST"

UPLOAD_LIST="aspera-upload_$(date '+%Y-%m-%d_%H:%M:%S').txt"
for FILENAME in $(cat "$FILE_LIST"); do
  if [ -e "$FILENAME.gpg" ]; then
    echo "$FILENAME.gpg" >> "$UPLOAD_LIST"
  fi
  if [ -e "$FILENAME.gpg.md5sum" ];
    echo "$FILENAME.gpg.md5sum" >> "$UPLOAD_LIST"
  fi
done

for FILE in $(cat "$UPLOAD_LIST")
do
  ascp -k2 -Q -l100M -L $WORKDIR $FILE $ASPERA_DESTINATION
done
