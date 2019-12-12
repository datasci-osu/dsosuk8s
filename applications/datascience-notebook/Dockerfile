FROM jupyter/datascience-notebook:7a0c7325e470

USER root

# TODO: see if these are necessary
#RUN pip install wheel
#RUN pip install jupyterhub

#RUN jupyter labextension install theme-dark-extension

RUN jupyter labextension install jupyterlab-topbar-extension \
                             jupyterlab-system-monitor \
                             jupyterlab-topbar-text \
                             jupyterlab-logout \
                             jupyterlab-theme-toggle


RUN rm -rf /home/jovyan/.cache/yarn

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    htop \
    nfs-common \
    nfs-kernel-server \
    svn \
    vim \
 && apt-get clean && rm -rf /var/lib/apt/lists/*


COPY start.sh /usr/local/bin/

RUN mkdir -p /usr/local/bin/start-notebook.d
COPY ./start-notebook.d/. /usr/local/bin/start-notebook.d/

USER $NB_USER
