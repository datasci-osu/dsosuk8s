FROM jupyter/datascience-notebook:7a0c7325e470

USER root


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
#RUN jupyter labextension install @jupyterlab/server-proxy

# these are listed in the dockerfile example in https://github.com/jupyterhub/jupyter-server-proxy/blob/master/contrib/rstudio/Dockerfile,
# we add them to the start_nfs.sh script in startup_scripts (set like PATH, PYTHONPATH, etc.)
#ENV PATH="${PATH}:/usr/lib/rstudio-server/bin"
#ENV LD_LIBRARY_PATH="/usr/lib/R/lib:/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server:/opt/conda/lib/R/lib"

USER $NB_USER


