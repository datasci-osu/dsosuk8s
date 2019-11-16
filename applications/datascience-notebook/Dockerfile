FROM jupyter/datascience-notebook:45f07a14b422

USER root

# TODO: see if these are necessary
RUN pip install wheel
RUN pip install jupyterhub

#RUN jupyter labextension install theme-dark-extension

RUN jupyter labextension install jupyterlab-topbar-extension \
                             jupyterlab-system-monitor \
                             jupyterlab-topbar-text \
                             jupyterlab-logout \
                             jupyterlab-theme-toggle


RUN rm -rf /home/jovyan/.cache/yarn

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    nfs-common \
    nfs-kernel-server \
    vim \
    htop \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY start.sh /usr/local/bin/
COPY start-notebook.d /usr/local/bin

USER $NB_USER
