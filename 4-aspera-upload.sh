#!/bin/bash

# check if user updated the aspera password and destination
# TODO: this check will become more important once we extract these settings
#   to an external, project-specific file
if [ -z $ASPERA_SCP_PASS -o -z $ASPERA_HOST -o -z $ASPERA_USER ]; then
  >&2 echo "ERROR: Aspera environment variables not set! exiting!
  (\$ASPERA_SCP_PASS, \$ASPERA_HOST and \$ASPERA_HOST)"
  exit 1
fi

# check if the aspera settings were updated, or contain the "TODO" marker
# note that this substring scan requires the more advanced double-bracket test: [[
#   this doesn't work in all shells, so we require bash
# see also: http://timmurphy.org/2013/05/13/string-contains-substring-in-bash/
if [[ ("$ASPERA_SCP_PASS" =~ "TODO") || ("$ASPERA_USER" =~ "TODO") ]]; then
  >&2 echo "ERROR: Aspera environment variables still contain \"TODO\", exiting!
  Did you already change them to the correct box+password for this submission?"
  exit 1
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

echo "using file-list: $FILE_LIST"


# convert "raw" list of bamfiles to list of encrypted versions and checksums
UPLOAD_LIST="_aspera-upload_$(date '+%Y-%m-%d_%H:%M:%S').txt"
while read -r UNENCRYPTED; do
  for EXTENSION in 'md5' 'gpg.md5' 'gpg'; do
    FILE="$UNENCRYPTED.$EXTENSION"
    if [ -e "$FILE" ]; then
      echo "$FILE" >> "$UPLOAD_LIST"
    else
      >&2 echo "WARNING: Expected file wasn't there: $FILE"
    fi
  done
done < "$FILE_LIST"


# Aspera upload:
#  -k2           --> set resume-mode to "attributes plus sparse file checksum"
#  --policy=fair --> try max data rate, but back off gently if congestion noticed (formerly -Q)
#  -l            --> max/target transfer rate (M --> Mbit/s)
#  -m 0          --> minimum transfer rate
#  -L .          --> output logs to local working dir
#  --file-list   --> list of files to upload this session, one path per line
#  --mode=send   --> the files in file-list should be sent TO the destination, not fetched
#
# more details:
#   http://download.asperasoft.com/download/docs/ascp/3.0/html/index.html
#
ascp \
  -k2 --policy=fair  -l 100M -m 0 \
  -L . \
  --file-list="$UPLOAD_LIST" --mode=send \
  --host=$ASPERA_HOST --user=$ASPERA_USER $ASPERA_FOLDER
