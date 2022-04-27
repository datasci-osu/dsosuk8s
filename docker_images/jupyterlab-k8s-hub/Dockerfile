FROM ubuntu:20.04 as jupyterlab-k8s-hub
#TAG: v1.5.8
#IMAGE: cjkeist/jupyterlab-k8s-hub

# VULN_SCAN_TIME=2021-08-04_01:01:30

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# psycopg2-binary in requirements.txt is not compiled for linux/arm64
# TODO: Use build stages to compile psycopg2-binary separately instead of
# bloating the image size
RUN EXTRA_APT_PACKAGES=; \
    if [ `uname -m` != 'x86_64' ]; then EXTRA_APT_PACKAGES=libpq-dev; fi; \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git \
      vim \
      less \
      python3 \
      python3-dev \
      python3-pip \
      python3-setuptools \
      python3-wheel \
      libssl-dev \
      libcurl4-openssl-dev \
      build-essential \
      sqlite3 \
      curl \
      dnsutils \
      $EXTRA_APT_PACKAGES \
      && \
    rm -rf /var/lib/apt/lists/*

ARG NB_USER=jovyan
ARG NB_UID=1000
ARG HOME=/home/jovyan

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    --home ${HOME} \
    --force-badname \
    ${NB_USER}

COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --upgrade --no-cache-dir \
        setuptools \
        pip
RUN PYCURL_SSL_LIBRARY=openssl \
    pip install --no-cache-dir \
        -r /tmp/requirements.txt

# Support overriding a package or two through passed docker --build-args.
# ARG PIP_OVERRIDES="jupyterhub==1.3.0 git+https://github.com/consideratio/kubespawner.git"
ARG PIP_OVERRIDES=
RUN if test -n "$PIP_OVERRIDES"; then \
        pip install --no-cache-dir $PIP_OVERRIDES; \
    fi

WORKDIR /srv/jupyterhub

# So we can actually write a db file here
RUN chown ${NB_USER}:${NB_USER} /srv/jupyterhub

# JupyterHub API port
EXPOSE 8081

# when building the dependencies image
# add pip-tools necessary for computing dependencies
# this is not done in production builds by chartpress
ARG PIP_TOOLS=
RUN test -z "$PIP_TOOLS" || pip install --no-cache pip-tools==$PIP_TOOLS

USER ${NB_USER}
CMD ["jupyterhub", "--config", "/usr/local/etc/jupyterhub/jupyterhub_config.py"]

########################
### End z2jh base
########################


USER root

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    htop \
    nfs-common \
    nfs-kernel-server \
    subversion \
    sudo \
    vim \
 && apt-get clean && rm -rf /var/lib/apt/lists/*


# The master has a bunch of bugfixes that need to be pulled
#RUN pip3 install jupyterhub-nativeauthenticator

# created a fork that has most of the pull requests, 
# but not this one which is buggy: https://github.com/jupyterhub/nativeauthenticator/pull/88
# we'll put it in /usr/local/lib/nativeauthenticator

# to use the fancy template (https://github.com/jupyterhub/nativeauthenticator/pull/79)
# add c.JupyterHub.template_paths = ["/usr/local/lib/nativeauthenticator/nativeauthenticator/templates/"] to config
# (/home/jovyan is the container user, so that's where we have write/install privs other than /tmp)
WORKDIR /usr/local/bin
# RUN git clone https://github.com/oneilsh/nativeauthenticator.git
RUN git clone https://github.com/jupyterhub/nativeauthenticator.git
WORKDIR /usr/local/bin/nativeauthenticator
RUN pip3 install .

# gotta to go /root for pip install to be global and overwrite the existing ltiauthenticator
WORKDIR /root
RUN pip3 install jupyterhub-ltiauthenticator
RUN pip3 install git+https://github.com/oneilsh/ltiauthenticator.git@multi-key

# TARGET jupyterlab-k8s-hub v1.5.8

# changelog
# 1.5.8; 11/29/21 - Upgrade to version 1.5 for jupyterhub
# 1.5.7; 11/29/21 - fixing hub version
# 1.5.6; 6/9/21 - another dependabot update, to cryptography==3.3.2
# 1.5.5; 6/9/21 - updated libs due to github dependabot alerts (rsa, PyYAML, jinja2, cryptography; urllib3 cannot be updated [conflict] but is a denial of service risk only, https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-33503)
# 1.5.4; 2/26/21 - added back nativeauthentictor, udpate to latest jupyterhub 1.3

WORKDIR /srv/jupyterhub

# leave running as root for start-hub.sh from the chart to do it's thing (possibly I should bake more into the images since I'm forking anyway)
