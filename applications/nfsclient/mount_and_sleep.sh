#!/usr/bin/env bash

# exit with error if any command fails
set -e

mount $NFS_SVC:/ /mnt/nfsmount

while true; do
	echo -e '\n'
	date;
	sleep 120; 
	df -h;
done
