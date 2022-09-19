#!/bin/bash

# this script runs as root - it will mount the remove server (if specified via NFS_HOME_SVC) to /nfs_home, ensure that /nfs_home/.hub_local/automanaged/hub_user_db exists and is propery owned,
# link /srv/jupyterhub to it so that the hub db info is written to the nfs share, and finally run jupyterhub with sudo in that dir
cd /usr/local/bin
pip install kubernetes-asyncio
source /usr/local/bin/data/common.src 

set_common_vars
create_uids_gids

do_mount $NFS_SVC_HOME /home

# there's no NB_USER defined for the hub, so we don't worry about things in the home directory or the site-libs
create-dir-structure <( cat /usr/local/bin/data/structure.txt | grep -v -E 'NB_USER|NB_UID|PYTHONVERSION')

chown $ADMIN_USERNAME /srv/jupyterhub

git clone https://github.com/oneilsh/jh-profile-quota.git
cd jh-profile-quota
pip3 install .

cd /srv/jupyterhub
exec sudo -E -H -u $ADMIN_USERNAME -- sh -c 'umask 0007 && jupyterhub --config /usr/local/etc/jupyterhub/jupyterhub_config.py'
