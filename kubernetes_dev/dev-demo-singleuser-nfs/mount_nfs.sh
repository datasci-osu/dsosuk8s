#!/bin/bash

set -e

echo "Checking for nfs mount request"

if [[ ! -z $NFS_SVC ]]; then 
  mkdir -p /mnt/nfsshare
  mount $NFS_SVC:/ /mnt/nfsshare
fi


