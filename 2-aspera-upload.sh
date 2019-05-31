#!/bin/bash

set -e

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
if [[ ("$ASPERA_SCP_PASS" =~ TODO) || ("$ASPERA_USER" =~ TODO) ]]; then
  >&2 echo "ERROR: Aspera environment variables still contain \"TODO\", exiting!
  Did you already change them to the correct box+password for this submission?"
  exit 1
fi

SPEED_LIMIT=${SPEED_LIMIT:-100M};


# Get list of ToDo files
# Either most-recent to-encrypt*.txt, OR whatever the user wants
#
# This should be the list of UNencrypted files, without any .gpg or .md5 extensions
# The script will automatically search for the .md5, .gpg and .gpg.md5 files
# (i.e. Use the same to_encrypt_list as for starting the encryption)
#
source "$(dirname "$BASH_SOURCE")/util.sh"
OVERRIDE_FILE="$1"
TO_ENCRYPT_LIST=$(get_default_or_override_to_encrypt_list "$OVERRIDE_FILE");
verify_to_encrypt_list "$TO_ENCRYPT_LIST"

# reasonable assumption where the encrypted files are: in the conventional workdir next to the encryption-list
WORKDIR="$( dirname "TO_ENCRYPT_LIST" )/files/"


TO_ENCRYPT_LIST_LINES=$( grep -c -v -e '^$' -e '^#' "$TO_ENCRYPT_LIST" )
echo "using file-list: $TO_ENCRYPT_LIST ($TO_ENCRYPT_LIST_LINES files)"
echo "Uploading to: $ASPERA_USER@$ASPERA_HOST:$ASPERA_FOLDER, setting SPEED_LIMIT=${SPEED_LIMIT}"


# If we have a logically named to-encrypt_list, use/create an upload-file with the matching time
#   otherwise, generate a new one with the current time.
if [[ "$TO_ENCRYPT_LIST" =~ (^.*/)?to-encrypt[-_] ]]; then
  UPLOAD_LIST=${TO_ENCRYPT_LIST//"to-encrypt"/"_aspera-upload"}
else
  UPLOAD_LIST="_aspera-upload_$(date '+%Y-%m-%d_%H:%M:%S').txt"
fi

# See if the upload-list already exists, if not, create and populate it:
if [ ! -e "$UPLOAD_LIST" ]; then
  echo "creating new upload list: $UPLOAD_LIST"
  # permission check: when using different users between the (often proxied/internetless )encryption/cluster and
  # the internet-enabled upload-machines, the permissions are sometimes wrong.
  echo "" > "$UPLOAD_LIST"
  if [ ! -e "$UPLOAD_LIST" ]; then
    >&2 echo "ERROR: couldn't create \"$UPLOAD_LIST\", do you have write permission on the folder?"
    exit 2
  fi

  # convert list of unencrypted files to list of encrypted versions plus checksums
  while read -r UNENCRYPTED; do
    for EXTENSION in 'md5' 'gpg.md5' 'gpg'; do
      FILE="$WORKDIR/$UNENCRYPTED.$EXTENSION"
      if [ -e "$FILE" ]; then
        echo "$FILE" >> "$UPLOAD_LIST"
      else
        >&2 echo "WARNING: Expected file wasn't there: $FILE"
      fi
    done
  done < "$TO_ENCRYPT_LIST"
else
  # If Upload-list exists, check if it is complete compared to the to-encrypt list
  #   (in case we aborted previous upload-runs while they were generating this list)
  UPLOADLIST_LINES=$( grep -c -v -e '^$' -e '^#' "$UPLOAD_LIST" )
  let "UPLOADLIST_TRIPLES = $UPLOADLIST_LINES/3";
  if [ "$UPLOADLIST_TRIPLES" -eq "$TO_ENCRYPT_LIST_LINES" ]; then
    echo "continuing with upload list: $UPLOAD_LIST ($UPLOADLIST_LINES files = $UPLOADLIST_TRIPLES triples)"
  else
    >&2 echo "ERROR: Upload list is too short compared to file list:
      to-encrypt list \"$TO_ENCRYPT_LIST\" is $TO_ENCRYPT_LIST_LINES lines
      expected an equal amount of triples in \"$UPLOAD_LIST\", but found $UPLOADLIST_TRIPLES ($UPLOADLIST_LINES lines)"
    exit 3
  fi
fi

# Aspera upload:
# These policies in line with EGA recommendations as of 2017-08-04:
#   https://ega-archive.org/submission/tools/ftp-aspera#UsingAspera
#   although the recommended transfer speed of "-l 300M" can and should be tuned
# More details on the parameters:
#   http://download.asperasoft.com/download/docs/ascp/3.0/html/index.html
#
#  -k2           --> set resume-mode to "attributes plus sparse file checksum"
#  --policy=fair --> try max data rate, but back off gently if congestion noticed (formerly -Q)
#  -T            --> disable encryption for better throughput; the transferred files are already gpg-encrypted
#  -l            --> max/target transfer rate (M --> Mbit/s)
#  -m 0          --> minimum transfer rate
#  -L            --> output logs to local working dir
#  --retry-timeout --> amount of seconds before completely aborting the transfer
#  --file-list   --> list of files to upload this session, one path per line
#  --mode=send   --> the files in file-list should be sent TO the destination, not fetched
#  -d            --> create target dir on receiver
#
ascp \
  -k2 --policy=fair -l "$SPEED_LIMIT" -m 0 \
  -T \
  -L "$(pwd)" \
  --retry-timeout=1800 \
  --file-list="$UPLOAD_LIST" --mode=send \
  -d \
  --host="$ASPERA_HOST" -P33001 --user="$ASPERA_USER" "$ASPERA_FOLDER"
ASPERA_EXIT_STATUS=$?
if [ $ASPERA_EXIT_STATUS -ne 0 ]; then
  >&2 echo "$(date '+%Y-%m-%d_%H:%M:%S'): WARNING: Aspera transfer exited with status $ASPERA_EXIT_STATUS";
else
  echo "$(date '+%Y-%m-%d_%H:%M:%S'): Aspera transfer completed succesfully!";
fi
