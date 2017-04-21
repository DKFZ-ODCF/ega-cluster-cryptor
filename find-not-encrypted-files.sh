comm -23 <(cat fileList.txt | sort) <(find `pwd` -type f -name "*.gpg" | sed "s/\.gpg//g" | sort)
