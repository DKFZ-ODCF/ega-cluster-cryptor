
# include utility functions
source ./util.sh;

OVERRIDE_FILE=$1

# default: use most-recent filelist in current working directory
FILE_LIST=$(get_default_or_override_fileList $OVERRIDE_FILE);
verify_fileList $FILE_LIST

echo "in filelist.txt " $(cat $FILE_LIST | wc -l)
echo "encrypted successfully " $(cat *.pipestatus | grep    "INTERNAL 0 0 0  EXTERNAL 0 0 0  " | wc -l)
echo "encryption failed "      $(cat *.pipestatus | grep -v "INTERNAL 0 0 0  EXTERNAL 0 0 0  " | wc -l)
