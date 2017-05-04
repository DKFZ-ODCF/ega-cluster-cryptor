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
INTERNAL=`mktemp`
EXTERNAL=`mktemp`

# extract filename from full path and rename if it's required
FILE=`basename $FULL_FILE | awk '{print $1}'`

# LINK FILE TO WORKDIR
# COMMENT OUT IF FILES ARE ALREADY LINKED !!!
# ln -s $FULL_FILE $FILE

# process file
#  Put all results into .partial files first, to signal that they are incomplete
cat $FILE | tee >( gpg -e --always-trust -r EGA_Public_key | tee $FILE.gpg.partial | md5sum > $FILE.gpg.md5.partial ; echo "INTERNAL ${PIPESTATUS[*]}" > $INTERNAL ) | md5sum > $FILE.md5.partial ; echo "EXTERNAL ${PIPESTATUS[*]}" > $EXTERNAL

# we're done, remove the ".partial" from the filenames
mv $FILE.gpg.partial     $FILE.gpg
mv $FILE.gpg.md5.partial $FILE.gpg.md5
mv $FILE.md5.partial     $FILE.md5

# store pipestatus into a file
echo "`cat $INTERNAL`  `cat $EXTERNAL`  $FILE" > $WORKDIR/$FILE.pipestatus
# delete pipestatus temp files
rm $INTERNAL $EXTERNAL
