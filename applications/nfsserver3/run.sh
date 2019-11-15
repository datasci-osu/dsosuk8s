#!/bin/bash
set -e

export_base="/nfsshare/"

### Handle `docker stop` for graceful shutdown
function shutdown {
    echo "- Shutting down nfs-server.."
    service nfs-kernel-server stop
    echo "- Nfs server is down"
    exit 0
}

trap "shutdown" SIGTERM
####

echo "Export points:"
echo "$export_base *(rw,sync,insecure,fsid=0,no_subtree_check)" | tee /etc/exports


echo -e "\n- Initializing nfs server.."
rpcbind
service nfs-kernel-server start


echo "- Nfs server is up and running.."

## Run forever
sleep infinity
