#!/bin/bash

# Job Name
#PBS -N ega-aspera-upload.sh
# cpu time
#PBS -l walltime=1000:00:00
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

export ASPERA_SCP_PASS="***REMOVED***";
export WORKDIR="$PWD";
cd $WORKDIR
ls -1 *.gpg *md5 > current-aspera-upload.txt
for FILE in $(cat current-aspera-upload.txt)
do
  ascp -k2 -Q -l100M -L $WORKDIR $FILE ***REMOVED***@fasp.ega.ebi.ac.uk:/.
done
