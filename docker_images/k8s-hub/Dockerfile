FROM jupyterhub/k8s-hub:0.9-484ce8e 

# The master has a bunch of bugfixes that need to be pulled
#RUN pip3 install jupyterhub-nativeauthenticator

#  this fork has em
WORKDIR /tmp
RUN git clone https://github.com/ml-tooling/nativeauthenticator.git
WORKDIR /tmp/nativeauthenticator
RUN pip3 install -e .

