#!/bin/bash

set -e

echo "Checking for /home mount request"

if [[ ! -z $NFS_HOME_SVC ]]; then 
  echo "NFS /home mount requested from $NFS_HOME_SVC"

  echo "Temporarily relocating /home/jovyan"
  cd /tmp
  mv /home/jovyan /tmp
  rm -rf /home/jovyan
  echo "Done relocting /home/jovyan to /tmp"

  echo "Mounting NFS to /home"
  mount $NFS_HOME_SVC:/ /home
  echo "Done mounting NFS to /home"

  echo "Relocting jovyan from /tmp back to /home"
  ls -lah /home
  sudo -u nobody mv /tmp/jovyan /home
  echo "Done relocting from /tmp back to /home"
  ls -lah /home

fi


