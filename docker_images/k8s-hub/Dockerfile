FROM jupyterhub/k8s-hub:0.9-484ce8e 

# The master has a bunch of bugfixes that need to be pulled
#RUN pip3 install jupyterhub-nativeauthenticator

# created a fork that has most of the pull requests, 
# but not this one which is buggy: https://github.com/jupyterhub/nativeauthenticator/pull/88
# we'll put it in /usr/local/lib/nativeauthenticator
# to use the fancy template (https://github.com/jupyterhub/nativeauthenticator/pull/79)
# add c.JupyterHub.template_paths = ["/usr/local/lib/nativeauthenticator/nativeauthenticator/templates/"] to config
# (/home/jovyan is the container user, so that's where we have write/install privs other than /tmp)
WORKDIR /home/jovyan
RUN git clone https://github.com/oneilsh/nativeauthenticator.git
WORKDIR /home/jovyan/nativeauthenticator
RUN pip3 install -e .

RUN pip3 install jupyterhub-ltiauthenticator
RUN pip3 install git+https://github.com/oneilsh/ltiauthenticator.git@master

#TAG v1.2.2
#TAG ext-roles-removed

WORKDIR /srv/jupyterhub

