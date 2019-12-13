FROM ubuntu:18.04

USER root

RUN apt update && apt install wget nfs-common -y

COPY mount_and_sleep.sh /
RUN chmod +x /mount_and_sleep.sh


CMD ["/mount_and_sleep.sh"]
