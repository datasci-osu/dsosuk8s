FROM ubuntu:18.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        netbase \
        nfs-kernel-server \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /nfsshare

EXPOSE 111/udp 2049/tcp 80/tcp

COPY nfs-kernel-server /etc/default/nfs-kernel-server

ADD run.sh /usr/local/bin/run.sh
ENTRYPOINT ["run.sh"]

#IMAGE oneilsh/nfsserver3
#TAG v1.0.1 
