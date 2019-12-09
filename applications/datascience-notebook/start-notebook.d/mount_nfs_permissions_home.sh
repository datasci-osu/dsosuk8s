#!/bin/bash

# Still TODO: stage a sourced_by_bashrcs in $ADMIN_HOME_DIR, add a source of it to all .bashrc files by default, allowing instructor control of environment customizations, 

set -e

echo "Checking for nfs mount request"


# if an NFS mount is being specified for /home...
if [[ ! -z $NFS_SVC_HOME ]]; then
  cd /tmp

  # pwd is /tmp, so use absolute path
  source /usr/local/bin/start-notebook.d/add_admin_group.src
  source /usr/local/bin/start-notebook.d/stage_home_copies.src  
  source /usr/local/bin/start-notebook.d/do_mount.src
  source /usr/local/bin/start-notebook.d/set_uid.src
  source /usr/local/bin/start-notebook.d/check_nb_user.src
  source /usr/local/bin/start-notebook.d/check_jovyan.src
  source /usr/local/bin/start-notebook.d/check_admin_config.src

  # ADMIN_USER is set by the chart's values.yaml depending on whether the user is listed as an admin in jupyterhub
  # everything should be setup before we try to do this (or else "user not found" error)
  if [ "$ADMIN_USER" = "True" ]; then
    adduser $NB_USER dsadmins
  fi
  # no matter what add users group; these need to be done to get the entries in /etc/groups, that way permissions
  # work properly (UID/GID in /etc/passwd isn't enough)
  adduser $NB_USER users

  # go the new dir rather than leaving CWD to be the no-longer existing original
  cd /home/$NB_USER
fi


