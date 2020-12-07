FROM jupyter/datascience-notebook:7a0c7325e470

USER root


RUN jupyter labextension install jupyterlab-topbar-extension \
                             jupyterlab-system-monitor \
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
ENV RSTUDIO_URL=http://download2.rstudio.org/server/bionic/amd64
RUN wget -q ${RSTUDIO_URL}/${RSTUDIO_PKG}
RUN dpkg -i ${RSTUDIO_PKG}
RUN rm ${RSTUDIO_PKG}

ENV SHINY_PKG=shiny-server-1.5.12.933-amd64.deb
ENV SHINY_URL=https://download3.rstudio.org/ubuntu-14.04/x86_64
RUN wget -q ${SHINY_URL}/${SHINY_PKG}
RUN dpkg -i ${SHINY_PKG}
RUN rm ${SHINY_PKG}

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*


#RUN pip install git+https://github.com/jupyterhub/jupyter-rsession-proxy
# use the pypi version to avoid a recent bug RE https://github.com/jupyterhub/jupyter-rsession-proxy/issues/71#issuecomment-523630103
RUN pip install 'jupyter-rsession-proxy==1.0b6'

# because of some error RE https://github.com/jupyter/docker-stacks/issues/927 
RUN conda install -c r r-stringi

# needed for launch icon? Sigh...
# https://github.com/jupyterhub/jupyter-server-proxy/issues/139#issuecomment-544763062
# a never version of jupyterlab should support jupyterlab-server-proxy, even though it's not the jupyerlab itself
# that is version conflicted, but some extension packages...
# (jupyter/datascience-notebook:7a0c7325e470 has jupyterlab 1.2.1)
## Conflicting Dependencies:
## JupyterLab              Extension      Package
## >=1.2.0 <1.3.0          >=0.19.1 <0.20.0@jupyterlab/application
## >=1.2.0 <1.3.0          >=0.19.1 <0.20.0@jupyterlab/launcher
#RUN jupyter labextension install jupyterlab-server-proxy-saulshanabrook
# trying this from an earlier comment....
#RUN cd /tmp/ && \
#    git clone --depth 1 https://github.com/jupyterhub/jupyter-server-proxy && \
#    cd jupyter-server-proxy/jupyterlab-server-proxy && \
#    npm install && npm run build && jupyter labextension link . && \
#    npm run build && jupyter lab build
## OK, NEITHER OF THOSE WORK. Maybe I can try and install a newer jupyterlab... let's see if this works RE https://www.npmjs.com/package/@jupyterlab/server-proxy
RUN jupyter labextension install @jupyterlab/server-proxy
# omg it leaves 270M of junk around in .cache - we copy around the /home/jovyan user dir to setup NB_USER home, so it needs to be light
RUN rm -rf /home/jovyan/.cache/yarn

# these are listed in the dockerfile example in https://github.com/jupyterhub/jupyter-server-proxy/blob/master/contrib/rstudio/Dockerfile,
# we add them to the start_nfs.sh script in startup_scripts (set like PATH, PYTHONPATH, etc.)
#ENV PATH="${PATH}:/usr/lib/rstudio-server/bin"
#ENV LD_LIBRARY_PATH="/usr/lib/R/lib:/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server:/opt/conda/lib/R/lib"

RUN mkdir -p /usr/local/bin/various

# extra stuff
RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    less \
    openssh-client \
    file \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip install bash_kernel
RUN python -m bash_kernel.install
RUN pip install jupyter_contrib_nbextensions && jupyter contrib nbextension install 
RUN pip install nbresuse

# fixup for shiny-server bookmarks (don't want to make adjustment in the jupyter-rsession-proxy where the shiny config is generated from)
RUN chmod o+w /var/lib/shiny-server

# R geospatial libs, need system install
RUN conda install -c conda-forge geos r-rgeos r-rgdal r-sf
#TAG v1.1.10
#TAG fileutil

#USER $NB_USER
USER root

