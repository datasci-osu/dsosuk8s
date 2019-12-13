FROM jupyter/base-notebook:lab-1.2.1


USER root

# TODO: see if these are necessary
#RUN pip install wheel
#RUN pip install jupyterhub

#RUN jupyter labextension install theme-dark-extension

RUN rm -rf /home/jovyan/.cache/yarn

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    nfs-common \
    nfs-kernel-server \
    vim \
    htop \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN jupyter labextension install jupyterlab-topbar-extension 
RUN jupyter labextension install jupyterlab-system-monitor

COPY start.sh /usr/local/bin/

RUN mkdir -p /usr/local/bin/start-notebook.d
COPY ./start-notebook.d/. /usr/local/bin/start-notebook.d/

USER $NB_USER
