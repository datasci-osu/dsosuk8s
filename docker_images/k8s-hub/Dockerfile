FROM jupyterhub/k8s-hub:0.9-484ce8e 

# The master has a bunch of bugfixes that need to be pulled
#RUN pip3 install jupyterhub-nativeauthenticator

# created a fork that has most of the pull requests, 
# but not this one which is buggy: https://github.com/jupyterhub/nativeauthenticator/pull/88
WORKDIR /tmp
RUN git clone https://github.com/oneilsh/nativeauthenticator.git
WORKDIR /tmp/nativeauthenticator
RUN pip3 install -e .

