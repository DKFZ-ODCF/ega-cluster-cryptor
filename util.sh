#!/bin/bash
# general purpose, re-usable functions for the submission scripts

get_most_recent_filelist() {
  echo $(ls -t filelist*.txt | head -n1)
}

# usage: FILE_LIST=get_existing_file_list(OPTIONAL_COMMAND_LINE_OVERRIDE)
get_default_or_override_filelist() {
  # default: use most-recent filelist in current working directory
  FILE_LIST=$(get_most_recent_filelist)

  # check for command line override
  if [ ! -z "$1" ]; then
    FILE_LIST=$1
  fi

  echo $FILE_LIST
}

verify_filelist() {
  FILE_LIST=$1;

  if [ -z $FILE_LIST ]; then
    echo "ERROR: no file list to compare against! Please:
    a) specify one on the command line, or
    b) make sure there are 'filelist*.txt' in the CURRENT working dir for auto-detection"
    exit 102
  fi

  if [ ! -e $FILE_LIST ]; then
    echo "ERROR: File not found: $FILE_LIST"
    exit 103
  fi
}
