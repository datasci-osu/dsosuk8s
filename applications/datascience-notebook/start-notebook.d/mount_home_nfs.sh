#!/bin/bash

set -e

echo "Checking for /home mount request"

if [[ -z $NFS_HOME_SVC ]]; then 
  echo "NFS /home mount requested from $NFS_HOME_SVC"

  echo "Temporarily relocating /home/jovyan"
  mv /home/jovyan /tmp
  echo "Done relocting /home/jovyan to /tmp"
  
  echo "Mounting NFS to /home"
  mount -o soft $NFS_HOME_SVC:/ /home
  echo "Done mounting NFS to /home"

  echo "Relocting jovyan from /tmp back to /home"
  mv /tmp/jovyan /home
 echo "Done relocting from /tmp back to /home"
fi


