#!/bin/bash
set -e

addgroup --gid 101 dsadmins
adduser --no-create-home --uid 1001 --gid 101 --disabled-password --disabled-login --gecos "" dsadmin

export_base="/nfsshare/"
chown dsadmin:dsadmins $export_base
chmod 775 $export_base

### Handle `docker stop` for graceful shutdown
function shutdown {
    echo "- Shutting down nfs-server.."
    service nfs-kernel-server stop
    # need to ensure unexport to get EBS vols to detach in kubernetes?
    # ref: https://github.com/kubernetes/kubernetes/issues/52906#issuecomment-331639298
    # nevermind, doesn't seem to work; still doesn't hurt to clean up I suppose
    rm -rf /etc/exports
    exportfs -Fu $export_base
    echo "- Nfs server is down"
    exit 0
}

trap "shutdown" SIGTERM
####

echo "Export points:"
# TODO: check on security for exports; we're not root squashing (not optimal), 
# and local kube dns won't resolve outside of namespace (right? good), but
# it may still be possible to address by nfssvc.namespace.svc.cluster.local - 
# this is probably ok (even preferred) if allowed within project, but not between projects. 
echo "$export_base *(rw,sync,insecure,fsid=0,no_subtree_check,no_root_squash)" | tee /etc/exports


echo -e "\n- Initializing nfs server.."
rpcbind
service nfs-kernel-server start


echo "- Nfs server is up and running.."

## Run forever
sleep infinity
