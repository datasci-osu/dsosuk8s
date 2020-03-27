#!/bin/bash

# this script runs as root - it will mount the remove server (if specified via NFS_HOME_SVC) to /nfs_home, ensure that /nfs_home/.hub_local/automanaged/hub_user_db exists and is propery owned,
# link /srv/jupyterhub to it so that the hub db info is written to the nfs share, and finally run jupyterhub with sudo in that dir

# TODO: this is repetitious with the singluser start.sh, need to refactor
# what's the best way to ensure a particular structure but allow users to edit? git? what about permissions? rsync?
export ADMIN_USERNAME=dsadmin
export ADMIN_GROUPNAME=dsadmins
export USER_GROUPNAME=dsusers
export ADMIN_GID=102               # ssh group is 101 by default
export USER_GID=103
export ADMIN_UID=1001

addgroup --gid $ADMIN_GID $ADMIN_GROUPNAME
addgroup --gid $USER_GID $USER_GROUPNAME
adduser --no-create-home --uid $ADMIN_UID --gid $ADMIN_GID --disabled-password --disabled-login --gecos "" $ADMIN_USERNAME
adduser $ADMIN_USERNAME users

ADMIN_HOME_DIR=/nfs_home/.hub_local

echo "Attempting mount at hub..."

mkdir -p /nfs_home
mount -o soft,timeo=100 $NFS_SVC_HOME:/ /nfs_home

echo "mounting done; "
mount

# if the dir doesn't exist, create it, write permissions only for admins
if [[ ! -d $ADMIN_HOME_DIR ]] ; then
  mkdir -p $ADMIN_HOME_DIR
  echo "This directory is used for hub-wide environment configuration, package and script installs, etc. It is read/writable by those in the admins group, but only readable by others." > $ADMIN_HOME_DIR/README.txt
  chown -R $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR
  chmod -R 775 $ADMIN_HOME_DIR
  chmod 664 $ADMIN_HOME_DIR/README.txt
fi

# other dirs...
if [[ ! -d $ADMIN_HOME_DIR/automanaged ]] ; then
  mkdir -p $ADMIN_HOME_DIR/automanaged
  echo "This dir managed continuously by hub login processes, please don't edit." > $ADMIN_HOME_DIR/automanaged/README.txt
  touch $ADMIN_HOME_DIR/automanaged/etc_group_admins
  touch $ADMIN_HOME_DIR/automanaged/etc_group_users
  chown -R $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR/automanaged
  chmod -R 775 $ADMIN_HOME_DIR/automanaged
  chmod 664 $ADMIN_HOME_DIR/automanaged/README.txt $ADMIN_HOME_DIR/automanaged/etc_group_users $ADMIN_HOME_DIR/automanaged/etc_group_admins
fi

if [[ ! -d $ADMIN_HOME_DIR/automanaged/hub_user_db ]] ; then
  mkdir -p $ADMIN_HOME_DIR/automanaged/hub_user_db
  chown -R $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR/automanaged/hub_user_db
  chmod -R 775 $ADMIN_HOME_DIR/automanaged/hub_user_db
fi

echo "relinking /srv/jupyterhub..."

rm -rf /srv/jupyterhub
ln -s $ADMIN_HOME_DIR/automanaged/hub_user_db /srv/jupyterhub

echo "relinking done;"
ls -lah /srv
ls -lah /srv/jupyterhub


cd /srv/jupyterhub
exec sudo -E -H -u $ADMIN_USERNAME jupyterhub --config /etc/jupyterhub/jupyterhub_config.py
