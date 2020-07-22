FROM jupyterhub/k8s-hub:0.9-484ce8e
# y doesn't v0.9.0 and later work with uid=0 for the singleuser containers???
#FROM jupyterhub/k8s-hub:0.9.1 

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
# WORKDIR /home/jovyan
# RUN git clone https://github.com/oneilsh/nativeauthenticator.git
# WORKDIR /home/jovyan/nativeauthenticator
# RUN pip3 install -e .

# gotta to go /root for pip install to be global and overwrite the existing ltiauthenticator
WORKDIR /root
RUN pip3 install jupyterhub-ltiauthenticator
RUN pip3 install git+https://github.com/oneilsh/ltiauthenticator.git@multi-key

#TAG v1.4.3
#TAG baseimage0.9.1

WORKDIR /srv/jupyterhub


# TODO: These can prolly be removed since I'm now specifying the command with kustomize (helm post install)
ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/usr/local/bin/start-hub.sh"]
