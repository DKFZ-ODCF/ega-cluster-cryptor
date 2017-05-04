#!/bin/bash


export ASPERA_SCP_PASS="TODO";
export ASPERA_DESTINATION="ega-box-TODO@fasp.ega.ebi.ac.uk:/."
export WORKDIR="$PWD";
cd $WORKDIR

ls -1 *.gpg *md5 > current-aspera-upload.txt
for FILE in $(cat current-aspera-upload.txt)
do
  ascp -k2 -Q -l100M -L $WORKDIR $FILE $ASPERA_DESTINATION
done
