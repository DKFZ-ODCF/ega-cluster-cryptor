#!/bin/bash

export ASPERA_SCP_PASS="TODO";
export ASPERA_DESTINATION="ega-box-TODO@fasp.ega.ebi.ac.uk:/."
export WORKDIR="$PWD";
cd $WORKDIR

#TODO: make file-list overridable
# Should take same fileList as script 2 & 3
# i.e. filelist WITHOUT .gpg and .md5sum in the names
ls -1 *.gpg *md5 > current-aspera-upload.txt

for FILE in $(cat current-aspera-upload.txt)
do
  ascp -k2 -Q -l100M -L $WORKDIR $FILE $ASPERA_DESTINATION
done
