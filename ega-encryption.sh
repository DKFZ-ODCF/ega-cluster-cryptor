#!/bin/bash

# Job Name
#PBS -N ega-encryption.sh
# cpu time
#PBS -l walltime=08:00:00
# request 1 node
#PBS -l nodes=1
#PBS -A io_throttle
# e-mail address where PBS messages will be sent to
#PBS -M ***REMOVED***
# e-mail should be sent to the user when the job begins (b), ends (e) or aborts (a)
#PBS -m ea
# Define a file where stderr will be redirected to
#PBS -e /home/USERNAME/submission-logs
# Define a file where stdout will be redirected to
#PBS -o /home/USERNAME/submission-logs

cd $WORKDIR

# set temp files
INTERNAL=$(mktemp --suffix="-encryption-pipestatus-internal")
EXTERNAL=$(mktemp --suffix="-encryption-pipestatus-external")
TOTAL_PIPESTATUS=$($WORKDIR/$FILE.pipestatus)

# extract filename from full path
FILE=$(basename $FULL_FILE)

# process file
#  Put all results into .partial files first, to signal that they are incomplete
cat $FILE | tee >(
    gpg -e --always-trust -r EGA_Public_key | tee \
        $FILE.gpg.partial \
        | md5sum > $FILE.gpg.md5.partial; \
    echo "INTERNAL ${PIPESTATUS[*]}" > $INTERNAL \
  ) \
  | md5sum > $FILE.md5.partial; \
  echo "EXTERNAL ${PIPESTATUS[*]}" > $EXTERNAL

# store pipestatus into a file
echo "$(cat $INTERNAL)  $(cat $EXTERNAL)  $FILE" > $TOTAL_PIPESTATUS
# delete pipestatus temp files
rm $INTERNAL $EXTERNAL

# we're done. Check if everything worked without problems, and
# rename our .partial files accordingly
if [ "$(cat $TOTAL_PIPESTATUS)" == "INTERNAL 0 0 0  EXTERNAL 0 0 0  $FILE" ]; then
  # success! no pipes broke :-D
  mv "$FILE.gpg.partial"     "$FILE.gpg"
  mv "$FILE.gpg.md5.partial" "$FILE.gpg.md5"
  mv "$FILE.md5.partial"     "$FILE.md5"
  rm $TOTAL_PIPESTATUS
else
  # failure! at least one pipe broke :-(
  mv "$FILE.gpg.partial"     "$FILE.gpg.failed"
  mv "$FILE.gpg.md5.partial" "$FILE.gpg.md5.failed"
  mv "$FILE.md5.partial"     "$FILE.md5.failed"
  # leave $TOTAL_PIPESTATUS around, in case people wish to debug.
  exit 1 # signal non-success to PBS
fi
