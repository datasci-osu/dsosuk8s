FROM ubuntu:18.04 as jupyterlab-k8s-hub
# forked from https://github.com/jupyterhub/zero-to-jupyterhub-k8s/blob/master/images/hub/Dockerfile

ARG JUPYTERHUB_VERSION=1.1.*

RUN apt-get update && \
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
      # libc-bin explicitly added and pinned 2020-06-10 for a CVE found with trivy
      # ref: https://github.com/jupyterhub/zero-to-jupyterhub-k8s/issues/1712#issuecomment-656425028
      ### libc-bin=2.27-3ubuntu1.2 \
      libc-bin \
      $(bash -c 'if [[ $JUPYTERHUB_VERSION == "git"* ]]; then \
        # workaround for https://bugs.launchpad.net/ubuntu/+source/nodejs/+bug/1794589
        echo nodejs=8.10.0~dfsg-2ubuntu0.2 nodejs-dev=8.10.0~dfsg-2ubuntu0.2 npm; \
      fi') \
      && \
    apt-get purge && apt-get clean

ARG NB_USER=jovyan
ARG NB_UID=1000
ARG HOME=/home/jovyan

ENV LANG C.UTF-8

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    --home ${HOME} \
    --force-badname \
    ${NB_USER}

RUN python3 -m pip install --upgrade --no-cache setuptools pip
COPY requirements.txt /tmp/requirements.txt
RUN PYCURL_SSL_LIBRARY=openssl pip3 install --no-cache-dir \
         -r /tmp/requirements.txt \
         $(bash -c 'if [[ $JUPYTERHUB_VERSION == "git"* ]]; then \
            echo ${JUPYTERHUB_VERSION}; \
          else \
            echo jupyterhub==${JUPYTERHUB_VERSION}; \
          fi')

WORKDIR /srv/jupyterhub

# So we can actually write a db file here
# SHAWN - this doesnt matter, gets overriden in chart
RUN chown ${NB_USER}:${NB_USER} /srv/jupyterhub

# JupyterHub API port
EXPOSE 8081

# SHAWN - this doesn't matter, gets overriden in chart
USER ${NB_USER}
CMD ["jupyterhub", "--config", "/etc/jupyterhub/jupyterhub_config.py"]

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

# TARGET jupyterlab-k8s-hub v1.5.5 

# changelog
# 1.5.5; 6/9/21 - updated libs due to github dependabot alerts (rsa, PyYAML, jinja2, cryptography; urllib3 cannot be updated [conflict] but is a denial of service risk only, https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-33503)
# 1.5.4; 2/26/21 - added back nativeauthentictor, udpate to latest jupyterhub 1.3

WORKDIR /srv/jupyterhub

# leave running as root for start-hub.sh from the chart to do it's thing (possibly I should bake more into the images since I'm forking anyway)
