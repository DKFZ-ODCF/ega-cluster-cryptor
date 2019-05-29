#!/bin/bash
# general purpose, re-usable functions for the submission scripts

get_most_recent_to_encrypt_list() {
  # `find` is recommended for scripting, but sorting by modification time is _really_ annoying in that solution.
  ls -t to-encrypt*.txt 2> /dev/null | head -n1
}

# usage: TO_ENCRYPT_LIST=get_default_or_override_to_encrypt_list(COMMAND_LINE_OVERRIDE)
get_default_or_override_to_encrypt_list() {
  # default: use most-recent to_encrypt list in current working directory
  TO_ENCRYPT_LIST=$(get_most_recent_to_encrypt_list)

  # check for command line override
  if [ ! -z "$1" ]; then
    TO_ENCRYPT_LIST=$1
  fi

  echo "$TO_ENCRYPT_LIST"
}

verify_to_encrypt_list() {
  TO_ENCRYPT_LIST=$1;

  if [ -z "$TO_ENCRYPT_LIST" ]; then
    echo "ERROR: no file list to compare against! Please:
    a) specify one on the command line, or
    b) make sure there are 'to-encrypt*.txt' in the CURRENT working dir for auto-detection"
    exit 102
  fi

  if [ ! -e "$TO_ENCRYPT_LIST" ]; then
    echo "ERROR: File not found: $TO_ENCRYPT_LIST"
    exit 103
  fi
}
