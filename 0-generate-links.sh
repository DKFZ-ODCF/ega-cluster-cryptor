#!/bin/sh

# MAPFILE contains a two-column format:
#   1) path to the original file to upload
#   2) the alias/new name under which to upload it
# It can be separated by either (multiple) tabs, or a semicolon ";"
MAPFILE="$1"

# first argument not empty?
if [ -z "$MAPFILE" ]; then
  echo "ERROR: Please specify a mapping file containing the files to link"
  echo "  Usage: $0 /PATH/TO/MAPPING/FILE.txt"
  exit 1
fi

# does filename of first argument exist?
if [ ! -e "$MAPFILE" ]; then
  echo "ERROR: Could not find specified mapping file to link:"
  echo "  missing: $MAPFILE"
  exit 2
fi

# get date only once, so createlinks and filelist have the identical one, up to the second
DATE=$(date '+%Y-%m-%d_%H:%M:%S')

# prepare working subdir, so we don't clutter the current directory with dozens/hundreds of
# links and encrypted result files (1 original + 1 encrypted + 2 checksums adds up fast!)
WORKDIR='files'
if [ ! -d "$WORKDIR" ]; then
  mkdir "$WORKDIR"
fi

# prepare soft links generation for all files in MAPFILE
#   grep -> ignore empty and/or comment lines
#   sed  -> canonicalize column separators for consumtion by awk
FILE_LIST="filelist_$DATE.txt"
LINK_SCRIPT="_create_links-$DATE.sh"
 grep -v -e '^$' -e '^#' "$MAPFILE" | \
 sort | \
 awk -F '[;\t]+' \
   -v cwd="$(pwd)"  \
   -v workdir="$WORKDIR" \
   -v filelist="filelist_$DATE.txt" \
   -v linkscript="$LINK_SCRIPT" \
   '{
      linkname = workdir "/" $2;
      print cwd "/"          linkname > filelist;
      print "ln -s " $1 "  " linkname > linkscript;
    }'

# print blank line, to highlight any errors the linking might produce
# such as double file-names
echo
# actually create softlinks
sh $LINK_SCRIPT;
# and another blank line to "close"
echo

#create list of all links in folder
# TODO: make emit non-absolute paths
echo "done! newly created links in:   $FILE_LIST"

