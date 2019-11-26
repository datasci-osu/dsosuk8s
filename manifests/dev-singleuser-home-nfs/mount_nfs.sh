#!/bin/bash

set -e

echo "Checking for nfs mount request"

if [[ ! -z $NFS_SVC ]]; then 
  addgroup --gid 101 dsadmins
  adduser --no-create-home --uid 1001 --gid 101 --disabled-password --disabled-login --gecos "" dsadmin
  mkdir -p /mnt/nfstest
  mount -o nolock $NFS_SVC:/ /mnt/nfstest
  sleep infinity
  #ls -lah /home/jovyan/.npm/_cacache/content-v2/sha512/58/0a/0475fcd448d9b086b69be3da8131d9d978fe929b9b329423fbf88c0bab829f1d17be8144bb932c7840dc6e0564c4c0a3c63f93a8f1a69e03c50024b190dd
  ##mkdir -p /mnt/nfsshare
  #sudo -u jovyan cp -r /home/jovyan /tmp
  #chown -R jovyan:users /tmp/jovyan
  #chmod -R o+w /tmp/jovyan
  #mount $NFS_SVC:/ /home
  #sudo -u jovyan -g admins cp -r /tmp/jovyan /home
fi


