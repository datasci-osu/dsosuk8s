FROM jupyter/datascience-notebook:45f07a14b422

USER root

RUN pip install wheel
RUN pip install jupyterhub

#RUN jupyter labextension install theme-dark-extension

RUN jupyter labextension install jupyterlab-topbar-extension \
                             jupyterlab-system-monitor \
                             jupyterlab-topbar-text \
                             jupyterlab-logout \
                             jupyterlab-theme-toggle


COPY start.sh /usr/local/bin/

RUN rm -rf /home/jovyan/.cache/yarn
RUN apt install nfs-common nfs-kernel-server


USER $NB_USER
