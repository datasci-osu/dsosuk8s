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

## Rstudio - based on https://github.com/jupyterhub/jupyter-server-proxy/blob/master/contrib/rstudio/Dockerfile

RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		libapparmor1 \
                libclang-dev \
		libedit2 \
		lsb-release \
		psmisc \
		libssl1.0.0 \
		;

# You can use rsession from rstudio's desktop package as well.
ENV RSTUDIO_PKG=rstudio-server-1.2.5019-amd64.deb

RUN wget -q http://download2.rstudio.org/server/bionic/amd64/${RSTUDIO_PKG}
RUN dpkg -i ${RSTUDIO_PKG}
RUN rm ${RSTUDIO_PKG}

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*


RUN pip install git+https://github.com/jupyterhub/jupyter-rsession-proxy

# these are listed in the dockerfile example in https://github.com/jupyterhub/jupyter-server-proxy/blob/master/contrib/rstudio/Dockerfile,
# but we'd need to tell the spawner to keep them in the spawned command; we could alternatively do it in the start_nfs.sh (set like PATH, PYTHONPATH, etc.)
## The desktop package uses /usr/lib/rstudio/bin
#ENV PATH="${PATH}:/usr/lib/rstudio-server/bin"
#ENV LD_LIBRARY_PATH="/usr/lib/R/lib:/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server:/opt/conda/lib/R/lib"

USER $NB_USER


