#!/bin/bash

set -e

echo "this script is a modification of the default jupyter-stack base-notebook start.sh; \
  we make the assumption the container is started as root; this pulls scripts
  from a github repo (just a subdir using svn) and calls out to them, which in turn
  do various user setup and NFS mounting."

svn export http://github.com/oneilsh/dsosuk8s/branches/cluster/live_assets/jupyterhub_nfs_startup/start_nfs.sh \
	--trust-server-cert-failures=unknown-ca \
	--non-interactive \
	/usr/local/bin/start_nfs.sh

svn export http://github.com/oneilsh/dsosuk8s/branches/cluster/live_assets/jupyterhub_nfs_startup/start-notebook.d \
	--trust-server-cert-failures=unknown-ca \
	--non-interactive \
	/usr/local/bin/start-notebook.d

#chmod u+x /usr/local/bin/start-notebook.d/mount_nfs_permissions_home.sh
#chmod u+x /usr/local/bin/start_nfs.sh
source /usr/local/bin/start_nfs.sh
