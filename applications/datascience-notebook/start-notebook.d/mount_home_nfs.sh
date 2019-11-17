#!/bin/bash

set -e

echo "Checking for /home mount request"

if [[ ! -z $NFS_HOME_SVC ]]; then 
  echo "NFS /home mount requested from $NFS_HOME_SVC"

  echo "Temporarily relocating /home/jovyan"
  mv /home/jovyan /tmp
  echo "Done relocting /home/jovyan to /tmp"
  
  echo "Mounting NFS to /home"
  mount -o soft $NFS_HOME_SVC:/ /home
  echo "Done mounting NFS to /home"

  echo "Relocting jovyan from /tmp back to /home"
  sudo -u nobody mv /tmp/jovyan /home
  echo "Done relocting from /tmp back to /home"

  # handle home and working directory if the username changed
  # SHAWN: it seems like this block should come before the one below, but on upstream it doesnt?
  # TODO: see why this is
  if [[ "$NB_USER" != "jovyan" ]]; then
      # changing username, make sure homedir exists
      # (it could be mounted, and we shouldn't create it if it already exists)
      if [[ ! -e "/home/$NB_USER" ]]; then
          echo "Relocating home dir to /home/$NB_USER"
	  ls -lah /home
          sudo -u nobody mv /home/jovyan "/home/$NB_USER" 
	  ls -lah /home
          echo "Done relocating."
      fi
      # if workdir is in /home/jovyan, cd to /home/$NB_USER
      if [[ "$PWD/" == "/home/jovyan/"* ]]; then
          newcwd="/home/$NB_USER/${PWD:13}"
          echo "Setting CWD to $newcwd"
          cd "$newcwd"
          echo "Done setting CWD."
      fi
  fi



fi


