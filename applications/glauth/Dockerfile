FROM busybox:1.31-glibc

USER root

COPY glauth64 /usr/sbin
RUN chmod u+x /usr/sbin/glauth64
RUN mkdir -p /etc/glauth

COPY cfg/sample-simple.cfg /etc/glauth/config.cfg

EXPOSE 389 636 5555

CMD ["/usr/sbin/glauth64", "-c", "/etc/glauth/config.cfg"]
