#!/bin/sh

# first argument not empty?
if [ -z "$1" ]; then
  echo "ERROR: Please specify a mapping file containing the files to link"
  echo "  Usage: $0 /PATH/TO/MAPPING/FILE.txt"
  exit 1
fi

# does filename of first argument exist?
if [ ! -e "$1" ]; then
  echo "ERROR: Could not find specified mapping file to link:"
  echo "  missing: $1"
  exit 2
fi

# get date only once, so createlinks and filelist have the identical one, up to the second
DATE=$(date '+%Y-%m-%d_%H:%M:%S')
WORKDIR='files'

# prepare soft links for all files in map-files.txt
if [ ! -d "$WORKDIR" ]; then
  mkdir "$WORKDIR"
fi

FILE_LIST="filelist_$DATE.txt"
LINK_SCRIPT="_create_links-$DATE.sh"
 grep -v -e '^$' -e '^#' "$1" | \
 sed -r 's/\t+/;/' |
 sort | \
 awk -F ';' \
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

