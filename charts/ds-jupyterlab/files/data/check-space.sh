# Author: CJ Keist
# Date: 01/27/22
# 
# Script prints our files larger that 1Gb and prints total disk usage in current folder
#
#!/bin/bash
# Set deliminter of space for the printf in the find command below
IFS=' '
echo "File sizes Greater that 1Gb in Size"
echo ""
find . -type f -size +1G -printf "%h/%f\n" | while read file
do
        echo "SIZE: `/usr/bin/du -sh $file`"
done

echo ""
echo "Total space used in home folder: `/usr/bin/du -sh .`"
