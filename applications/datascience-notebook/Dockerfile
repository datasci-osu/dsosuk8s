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

USER $NB_USER
