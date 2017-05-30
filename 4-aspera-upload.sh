#!/bin/bash

# TODO: extract to project-specif file, outside of repo
export ASPERA_SCP_PASS="TODO";
export ASPERA_DESTINATION="ega-box-TODO@fasp.ega.ebi.ac.uk:/."


# check if user updated the aspera password and destination
# TODO: this check will become more important once we extract these settings
#   to an external, project-specific file
if [ -z $ASPERA_SCP_PASS -o -z $ASPERA_DESTINATION ]; then
  >&2 echo "ERROR: Aspera environment variables not set! exiting!
  (\$ASPERA_SCP_PASS and \$ASPERA_DESTINATION)"
fi

# check if the aspera settings were updated, or contain the "TODO" marker
# note that this substring scan requires the more advanced double-bracket test: [[
#   this doesn't work in all shells, so we require bash
# see also: http://timmurphy.org/2013/05/13/string-contains-substring-in-bash/
if [[ ("$ASPERA_SCP_PASS" =~ "TODO") || ("$ASPERA_DESTINATION" =~ "TODO") ]]; then
  >&2 echo "ERROR: Aspera environment variables still contain \"TODO\", exiting!
  Did you already change them to the correct box+password for this submission?"
fi


# Get list of ToDo files
# Either most-recent fileList*.txt, OR whatever the user wants
#
# This should be the list of UNencrypted files, without any .gpg or .md5 extensions
# The script will automatically search for the .md5, .gpg and .gpg.md5 files
# (i.e. Use the same fileList as for starting the encryption)
#
source ${BASH_SOURCE%/*}/util.sh;
OVERRIDE_FILE="$1"
FILE_LIST=$(get_default_or_override_fileList "$OVERRIDE_FILE");
verify_fileList "$FILE_LIST"

# convert "raw" list of bamfiles to encrypted versions and checksums
UPLOAD_LIST="_aspera-upload_$(date '+%Y-%m-%d_%H:%M:%S').txt"
while read -r UNENCRYPTED; do
  for EXTENSION in 'md5' 'gpg' 'gpg.md5'; do
    FILE="$UNENCRYPTED.$EXTENSION"
    if [ -e "$FILE" ]; then
      echo "$FILE" >> "$UPLOAD_LIST"
    else
      echo "File not found: $FILE"
    fi
  done
done < "$FILE_LIST"

# Actually upload all files
# TODO: ascp has a --file-list=$FILE option, maybe better?
#   A single session with multiple files saves a lot of restarting/handshaking
#   Especially for tiny-tiny md5sum files...
while read -r FILE; do
  ascp -k2 -Q -l100M -L $WORKDIR $FILE $ASPERA_DESTINATION
done < "$UPLOAD_LIST"
