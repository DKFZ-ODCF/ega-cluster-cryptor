#!/bin/bash

# check if user updated the aspera password and destination
if [[ -z ${ASPERA_SCP_PASS}  || -z ${ASPERA_HOST} || -z ${ASPERA_USER} ]] ; then
  >&2 echo "ERROR: Aspera environment variables not set! exiting!
  (variable names: \$ASPERA_SCP_PASS, \$ASPERA_HOST and \$ASPERA_USER)
  did you \`source\` the correct aspera-env file?"
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
# Either most-recent filelist*.txt, OR whatever the user wants
#
# This should be the list of UNencrypted files, without any .gpg or .md5 extensions
# The script will automatically search for the .md5, .gpg and .gpg.md5 files
# (i.e. Use the same filelist as for starting the encryption)
#
source "${BASH_SOURCE%/*}/util.sh";
OVERRIDE_FILE="$1"
FILE_LIST=$(get_default_or_override_filelist "$OVERRIDE_FILE");
verify_filelist "$FILE_LIST"

FILELIST_LINES=$( grep -c -v -e '^$' -e '^#' "$FILE_LIST" )
echo "using file-list: $FILE_LIST ($FILELIST_LINES files)"
echo "Uploading to: $ASPERA_USER@$ASPERA_HOST:$ASPERA_FOLDER"


# If we have a time-stamped file-list, use/create an upload-file with the matching time
#   otherwise, generate a new one with the current time.
if [[ "$FILE_LIST" =~ (^.*/)?filelist[-_] ]]; then
  UPLOAD_LIST=${FILE_LIST//"filelist"/"_aspera-upload"}
else
  UPLOAD_LIST="_aspera-upload_$(date '+%Y-%m-%d_%H:%M:%S').txt"
fi

# See if the upload-list already exists, if not, create and populate it:
# convert list of unencrypted files to list of encrypted versions plus checksums
if [ ! -e "$UPLOAD_LIST" ]; then
  echo "creating new upload list: $UPLOAD_LIST"
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
else
  UPLOADLIST_LINES=$( grep -c -v -e '^$' -e '^#' "$UPLOAD_LIST" )
  let "UPLOADLIST_TRIPLES = $UPLOADLIST_LINES/3";
  if [ "$UPLOADLIST_TRIPLES" -eq "$FILELIST_LINES" ]; then
    echo "continuing with upload list: $UPLOAD_LIST ($UPLOADLIST_LINES files = $UPLOADLIST_TRIPLES triples)"
  else
    >&2 echo "ERROR: Upload list is too short compared to file list:
      filelist \"$FILE_LIST\" is $FILELIST_LINES lines
      expected an equal amount of triples in \"$UPLOAD_LIST\", but found $UPLOADLIST_TRIPLES ($UPLOADLIST_LINES lines)"
  fi
fi

# Aspera upload:
# These policies in line with EGA recommendations as of 2017-08-04:
#   https://ega-archive.org/submission/tools/ftp-aspera#UsingAspera
#   although the recommended transfer speed of "-l 300M" can be tuned
# More details on the parameters:
#   http://download.asperasoft.com/download/docs/ascp/3.0/html/index.html
#
#  -k2           --> set resume-mode to "attributes plus sparse file checksum"
#  --policy=fair --> try max data rate, but back off gently if congestion noticed (formerly -Q)
#  -T            --> disable encryption for better throughput; the transferred files are already gpg-encrypted
#  -l            --> max/target transfer rate (M --> Mbit/s)
#  -m 0          --> minimum transfer rate
#  -L .          --> output logs to local working dir
#  --file-list   --> list of files to upload this session, one path per line
#  --mode=send   --> the files in file-list should be sent TO the destination, not fetched
#
ascp \
  -k2 --policy=fair -l 300M -m 0 \
  -T \
  -L "$(pwd)" \
  --file-list="$UPLOAD_LIST" --mode=send \
  --host="$ASPERA_HOST" -P33001 --user="$ASPERA_USER" "$ASPERA_FOLDER"
