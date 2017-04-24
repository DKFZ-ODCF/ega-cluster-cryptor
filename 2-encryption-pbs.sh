# INFO: if you want to restart the encryption for a file, delete all the corresponding *.md5 and *.gpg files

# default: use most-recent filelist in current working directory
FILE_LIST=$(ls -t fileList*.txt | head -n1)

# check for command line override
if [ ! -z "$1" ]; then
  echo "using file list from command line: $1"
  FILE_LIST=$1;
else
  echo "using auto-detected file list: $FILE_LIST"
fi

if [ -z $FILE_LIST ]; then
  echo "ERROR: no file list to compare against! Please:
  a) specify one on the command line, or
  b) make sure there are 'fileList*.txt' in the CURRENT working dir for auto-detection"
  exit 2
fi

if [ ! -e $FILE_LIST ]; then
  echo "ERROR: File not found: $FILE_LIST"
  exit 3
fi

unencryptedFiles=$(comm -23 <(cat fileList.txt | sort) <(find `pwd` -type f -name "*.gpg" | sed "s/\.gpg//g" | sort))

WORKDIR=$(pwd)
for FULL_FILE in $unencryptedFiles
do
   qsub -v FULL_FILE=$FULL_FILE,WORKDIR=$WORKDIR ega-encryption.sh
done
