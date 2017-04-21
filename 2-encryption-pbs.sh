# INFO: if you want to restart the encryption for a file, delete all the corresponding *.md5 and *.gpg files


unencryptedFiles=$(comm -23 <(cat fileList.txt | sort) <(find `pwd` -type f -name "*.gpg" | sed "s/\.gpg//g" | sort))

WORKDIR=$(pwd)
for FULL_FILE in $unencryptedFiles
do
   qsub -v FULL_FILE=$FULL_FILE,WORKDIR=$WORKDIR ega-encryption.sh
done
