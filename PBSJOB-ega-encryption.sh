#!/bin/bash

# Job Name - can be set more-specific from qsub command
#PBS -N ega-encryption.sh
# cpu time, when not overriden by submitter
#PBS -l walltime=08:00:00,mem=400MB
# request 1 node
#PBS -l nodes=1
#PBS -A io_throttle

cd $WORKDIR

# extract filename from full path
FILE=$(basename $FULL_FILE)

# set temp files
INTERNAL=$(mktemp --suffix="-encryption-pipestatus-internal")
EXTERNAL=$(mktemp --suffix="-encryption-pipestatus-external")
TOTAL_PIPESTATUS="$FILE.pipestatus"

# process file
#  Put all results into .partial files first, to signal that they are incomplete
cat $FILE | tee >(
    gpg -e --always-trust -r EGA_Public_key | tee \
        "$FILE.gpg.partial" \
        | md5sum > "$FILE.gpg.md5.partial"; \
    echo "INTERNAL ${PIPESTATUS[*]}" > "$INTERNAL" \
  ) \
  | md5sum > $FILE.md5.partial; \
  echo "EXTERNAL ${PIPESTATUS[*]}" > "$EXTERNAL"
# store combined pipestatus into a file, delete intermediate tempfiles
echo "$(cat $INTERNAL)  $(cat $EXTERNAL)  $FILE" > "$TOTAL_PIPESTATUS"
rm "$INTERNAL" "$EXTERNAL"

#replace '-' label (STDIN) in md5 files with the actual file-name used
sed -i s/-/$FILE.gpg/ "$FILE.gpg.md5.partial"
sed -i s/-/$FILE/     "$FILE.md5.partial"

# we're done. Check if everything worked without problems, and
# rename our .partial files accordingly
if [ "$(cat $TOTAL_PIPESTATUS)" == "INTERNAL 0 0 0  EXTERNAL 0 0 0  $FILE" ]; then
  # success! no pipes broke :-D
  mv "$FILE.gpg.partial"     "$FILE.gpg"
  mv "$FILE.gpg.md5.partial" "$FILE.gpg.md5"
  mv "$FILE.md5.partial"     "$FILE.md5"
  rm "$TOTAL_PIPESTATUS" # not needed if everything worked :-)
else
  # failure! at least one pipe broke :-(
  mv "$FILE.gpg.partial"     "$FILE.gpg.failed"
  mv "$FILE.gpg.md5.partial" "$FILE.gpg.md5.failed"
  mv "$FILE.md5.partial"     "$FILE.md5.failed"
  # leave $TOTAL_PIPESTATUS around, in case people wish to debug.
  exit 1 # signal non-success to PBS
fi
