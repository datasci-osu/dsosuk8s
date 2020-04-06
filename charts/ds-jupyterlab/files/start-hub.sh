#!/bin/bash

# this script runs as root - it will mount the remove server (if specified via NFS_HOME_SVC) to /nfs_home, ensure that /nfs_home/.hub_local/automanaged/hub_user_db exists and is propery owned,
# link /srv/jupyterhub to it so that the hub db info is written to the nfs share, and finally run jupyterhub with sudo in that dir
cd /tmp

source /usr/local/bin/data/common.src 

set_common_vars
create_uids_gids

do_mount $NFS_SVC_HOME /home


echo "relinking /srv/jupyterhub..."

rm -rf /srv/jupyterhub
ln -s $ADMIN_HOME_DIR/automanaged/hub_user_db /srv/jupyterhub

echo "relinking done;"
ls -lah /srv
ls -lah /srv/jupyterhub


cd /srv/jupyterhub
exec sudo -E -H -u $ADMIN_USERNAME -- sh -c 'umask 0007 && jupyterhub --config /etc/jupyterhub/jupyterhub_config.py'
