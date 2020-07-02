#!/bin/sh

# MAPFILE contains a two-column format:
#   1) path to the original file to upload, as absolute path
#   2) the alias/new name under which to upload it
# It can be separated by either (multiple) tabs, or a semicolon ";"
# Empty lines and lines starting with '#' (comments) are ignored.
MAPFILE="$1"

set -u

# first argument not empty?
if [ -z "$MAPFILE" ]; then
  >&2 echo -e "\e[91mERROR:\e[39m Please specify a mapping file containing the files to link"
  >&2 echo "  Usage: $0 /PATH/TO/MAPPING/FILE.txt"
  exit 1
fi

# does filename of first argument exist?
if [ ! -e "$MAPFILE" ]; then
  >&2 echo -e "\e[91mERROR:\e[39m Could not find specified mapping file to link:"
  >&2 echo "  missing: $MAPFILE"
  exit 2
fi

# prepare working subdir, so we don't clutter the current directory with dozens/hundreds of
# links and encrypted result files (1 original + 1 encrypted + 2 checksums adds up fast!)
WORKDIR='files'
if [ ! -d "$WORKDIR" ]; then
  mkdir "$WORKDIR"
fi

# output file
TO_ENCRYPT_LIST="to-encrypt_$(date '+%Y-%m-%d_%H:%M:%S').txt"

touch "$TO_ENCRYPT_LIST" # generate an empty file, even if all file-paths error out.

# grep to ignore comments and empty lines
# IFS: split on tabs and/or semicolon
#      \r to swallow leftovers from DOS line endings.
grep -v -e '^#' -e '^\w*$' "$MAPFILE" | while IFS=$'\t;\r' read -r LOCALABSPATH EGANAME; do
  if [ -e "$LOCALABSPATH" ]; then
    echo "$EGANAME" >> "$TO_ENCRYPT_LIST"
    ln -s "${LOCALABSPATH}" "${WORKDIR}/${EGANAME}"
  else
    >&2 echo -e "\e[93mWARNING:\e[39m ${LOCALABSPATH} not found; skipping!"
  fi
done

echo -e "\e[92mDone!\e[39m Newly created links in:   $TO_ENCRYPT_LIST"

