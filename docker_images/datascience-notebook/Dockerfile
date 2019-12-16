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
    subversion \
    vim \
 && apt-get clean && rm -rf /var/lib/apt/lists/*


COPY start.sh /usr/local/bin/

# the default image has /opt writable by the jovyan user, but anything installed there (e.g. w/ pip install)
# will disappear once the container goes away, so let's just make it unwritable and avoid accidental installs there
RUN chown -R root:root /opt
#RUN mkdir -p /usr/local/bin/start-notebook.d
#COPY ./start-notebook.d/. /usr/local/bin/start-notebook.d/


USER $NB_USER
