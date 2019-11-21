#!/usr/bin/env bash

# exit with error if any command fails
set -e


mkdir -p $TARGET_DIR
mount -o nolock $NFS_SVC:/ $TARGET_DIR

while true; do
	echo -e '\n'
	date;
	sleep 120; 
	df -h;
done
