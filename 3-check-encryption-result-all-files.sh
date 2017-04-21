echo in filelist.txt $(cat fileList.txt | wc -l)
echo encrypted successfully $(cat *.pipestatus | grep "INTERNAL 0 0 0  EXTERNAL 0 0 0  " | wc -l)
echo encryption failed $(cat *.pipestatus | grep -v "INTERNAL 0 0 0  EXTERNAL 0 0 0  " | wc -l)
