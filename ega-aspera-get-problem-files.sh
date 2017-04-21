comm -23 <(cat current-aspera-upload.txt | sort) <(bash ega-aspera-get-skipped-files.sh | sort)
