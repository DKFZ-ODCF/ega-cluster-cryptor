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

DATE=$(date '+%Y-%m-%d_%H:%M:%S')

# prepare soft links for all files in map-files.txt
if [ ! -d 'files' ]; then
  mkdir 'files'
fi
LINK_SCRIPT="_create_links-$DATE.sh"
 grep -v -e '^$' -e '^#' "$1" | \
 sort | \
 awk -F ";" '{ print "ln -s " $1 " files/" $2  }' > $LINK_SCRIPT

# print blank line, to highlight any errors the linking might produce
# such as double file-names
echo
# actually create softlinks
sh $LINK_SCRIPT;
# and another blank line to "close"
echo

#create list of all links in folder
# TODO: make emit non-absolute paths
# TODO: maybe only list files that we linked? (For easier handling of batches)
ALL_LINKS="filelist_$DATE.txt"
find `pwd` -type l > $ALL_LINKS

echo "done! all links (including pre-existing ones):   $ALL_LINKS"

