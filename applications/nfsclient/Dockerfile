FROM ubuntu:18.04

USER root

RUN apt update
RUN apt install wget -y
RUN apt install nfs-common -y

RUN mkdir /mnt/nfsmount

COPY mount_and_sleep.sh /
RUN chmod +x /mount_and_sleep.sh


CMD ["/mount_and_sleep.sh"]
