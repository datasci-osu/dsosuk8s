FROM ubuntu:18.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        netbase \
        nfs-kernel-server \
        nodejs \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /nfsshare

EXPOSE 111/udp 2049/tcp 80/tcp

COPY app.js /
ADD run.sh /usr/local/bin/run.sh
ENTRYPOINT ["run.sh"]
