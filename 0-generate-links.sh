#!/bin/sh

if [ -z "$1" ]; then
  echo "ERROR: Please specify a mapping file containing the files to link"
  echo "  Usage: $0 /PATH/TO/MAPPING/FILE.txt"
  exit 1
fi

if [ ! -e "$1" ]; then
  echo "ERROR: Could not find specified mapping file to link:"
  echo "  missing: $1"
  exit 2
fi

# prepare soft links for all files in map-files.txt
LINK_SCRIPT="_create_links-$(date '+%Y-%m-%d_%H:%M:%S').sh"
cat "$1" | awk -F ";" '{print "ln -s "$1" "$2}' > $LINK_SCRIPT

# print blank line, to highlight any errors the linking might produce
# such as double file-names
echo
# actually create softlinks
sh $LINK_SCRIPT;
# and another blank line to "close"
echo

#create list of all links in folder
ALL_LINKS="fileList_$(date '+%Y-%m-%d_%H:%M:%S').txt"
find `pwd` -type l > $ALL_LINKS

echo "done! all links (including pre-existing ones):   $ALL_LINKS"

