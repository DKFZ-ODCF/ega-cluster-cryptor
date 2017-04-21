echo the script will try to upload `cat current-aspera-upload.txt | wc -l` 
echo 'successfully connected to ega and tried to transfer (succeed/failed/skipped)' `cat aspera-scp-transfer.*.log | grep "======= File Transfer statistics =======" | wc -l`
echo skipped `cat aspera-scp-transfer.*.log | grep -E "^.+LOG - Source file transfers skipped.+:.+1$" | wc  -l` 
