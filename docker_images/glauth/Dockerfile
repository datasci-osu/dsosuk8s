FROM ubuntu:18.04
# ubuntu:18.04 on dockerhub is a minimal install: https://ubuntu.com/blog/minimal-ubuntu-released

USER root

COPY glauth64 /usr/sbin
RUN chmod u+x /usr/sbin/glauth64
RUN mkdir -p /etc/glauth

COPY cfg/sample-simple.cfg /etc/glauth/config.cfg

EXPOSE 3893 3894 5555

CMD ["/usr/sbin/glauth64", "-c", "/etc/glauth/config.cfg"]
