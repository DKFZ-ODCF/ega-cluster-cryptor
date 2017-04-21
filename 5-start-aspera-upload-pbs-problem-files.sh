bash ega-aspera-get-problem-files.sh > tmp-current-aspera-upload.txt
cp tmp-current-aspera-upload.txt current-aspera-upload.txt
rm tmp-current-aspera-upload.txt
bash start-pbs-aspera-upload.sh
