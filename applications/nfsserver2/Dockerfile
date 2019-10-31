FROM erichough/nfs-server:2.2.1

USER root

RUN mkdir /nfsshare

EXPOSE 2049
EXPOSE 111
EXPOSE 32765
EXPOSE 32767
EXPOSE 2049/udp
EXPOSE 111/udp
EXPOSE 32765/udp
EXPOSE 32767/udp


ENV NFS_LOG_LEVEL DEBUG
#ENV NFS_DISABLE_VERSION_3 true
# it appears pods use 172.* as their clientaddr, setting all access; gotta check that
# access is namespace-limited (or figure some way to secure)
ENV NFS_EXPORT_0 "/nfsshare *(rw,fsid=0,async,no_subtree_check,no_auth_nlm,insecure,no_root_squash)" 
