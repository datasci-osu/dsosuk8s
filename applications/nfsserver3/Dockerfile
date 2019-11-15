FROM ubuntu:18.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        netbase \
        nfs-kernel-server \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /nfsshare
RUN chown nobody:nogroup /nfsshare
RUN chmod 755 /nfsshare

EXPOSE 111/udp 2049/tcp 80/tcp

ADD run.sh /usr/local/bin/run.sh
ENTRYPOINT ["run.sh"]
