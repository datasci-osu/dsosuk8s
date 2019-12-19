FROM itsthenetwork/nfs-server-alpine:12
# nfs server image based on alpine

USER root

# based on: https://github.com/thxCode/kubernetes-python-client/blob/master/Dockerfile
ENV KUBE_CLIENT_VERSION="4.0.0"
ENV KUBE_WS_PATCH_VERSION="2.0.98"

RUN apk add --update --no-cache \
		dumb-init \
		bash \
		sudo \
		python \
	&& apk add --no-cache --virtual=build-dependencies \
		python-dev \
		py-pip \
	&& pip install --no-cache-dir -U \
		passlib \
		kubernetes==${KUBE_CLIENT_VERSION} \
	#	kubernetes-ws-patch==${KUBE_WS_PATCH_VERSION} \
	&& apk del --purge build-dependencies \
	&& rm -fr \
		/var/cache/apk/* \
		/root/.cache \
		/tmp/*

COPY main.py /
RUN chmod u+x /main.py

COPY nfsd.sh /usr/bin/nfsd.sh
RUN chmod u+x /usr/bin/nfsd.sh

RUN mkdir /nfsshare

# use entrypoint from inherited container
