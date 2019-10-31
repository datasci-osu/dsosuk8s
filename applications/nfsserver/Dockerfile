FROM itsthenetwork/nfs-server-alpine:12
# nfs server image based on alpine


USER root

COPY nfsd.sh /usr/bin/nfsd.sh
RUN chmod u+x /usr/bin/nfsd.sh

# gotta check that networking is limited to within-namespace by kubernetes
ENV PERMITTED "10.0.0.0/8"

RUN mkdir /nfsshare

EXPOSE 2049
# use entrypoint from inherited container
