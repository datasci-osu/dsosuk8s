FROM jupyterlab-ubuntu-nvidia-scipy as jupyterlab-ubuntu-nvidia-scipy-rjulia
############################################################################
################ Dependency: jupyter/datascience-notebook ##################
############################################################################

# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

# Set when building on Travis so that certain long-running build steps can
# be skipped to shorten build time.
ARG TEST_ONLY_BUILD

USER root

# R pre-requisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-dejavu \
    gfortran \
    gcc && \
    rm -rf /var/lib/apt/lists/*

# Julia dependencies
# install Julia packages in /opt/julia instead of $HOME
ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.7.2

RUN mkdir /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    echo "a75244724f3b2de0e7249c861fbf64078257c16fb4203be78f1cf4dd5973ba95 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C /opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

# Show Julia where conda libraries are \
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown $NB_USER $JULIA_PKGDIR
    #fix-permissions $JULIA_PKGDIR


# R packages including IRKernel which gets installed globally.
RUN conda install --quiet --yes -c conda-forge mamba
#RUN conda install --quiet --yes 'r-base=4.1.*'
RUN mamba install --quiet --yes 'r-base=4.2.*'
    #'r-caret=6.0*' \
    #'r-crayon=1.3*' \
RUN mamba install --quiet --yes 'r-devtools=2.4*'
    #'r-forecast=8.10*' \
    #'r-hexbin=1.28*' \
RUN mamba install --quiet --yes 'r-htmltools=0.5*'
RUN mamba install --quiet --yes 'r-htmlwidgets=1.5*'
RUN mamba install --quiet --yes 'r-irkernel=1.3*'
    #'r-nycflights13=1.0*' \
#    'r-plyr=1.8*' \
    #'r-randomforest=4.6*' \
RUN mamba install --quiet --yes 'r-rcurl=1.98*'
#    'r-reshape2=1.4*' \
RUN mamba install --quiet --yes 'r-rmarkdown=2.14'
RUN mamba install --quiet --yes 'r-rsqlite=2.2*'
RUN mamba install --quiet --yes 'r-shiny=1.7*'
    #'r-tidyverse=1.3*' \
#    'rpy2=3.1*' \
RUN mamba clean --all -f -y
    #fix-permissions $CONDA_DIR && \
    #fix-permissions /home/$NB_USER
# Fix to get R - recognize zlib
RUN cp /etc/apt/sources.list /etc/apt/sources.list~
RUN sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
RUN apt-get update -y
RUN apt-get build-dep r-base -y
# Add Julia packages. Only add HDF5 if this is not a test-only build since
# it takes roughly half the entire build time of all of the images on Travis
# to add this one package and often causes Travis to timeout.
#
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.
RUN julia -e 'import Pkg; Pkg.update()' && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("HDF5")') && \
    julia -e "using Pkg; pkg\"add IJulia\"; pkg\"precompile\"" && \
    # move kernelspec out of home \
    mv $HOME/.local/share/jupyter/kernels/julia* $CONDA_DIR/share/jupyter/kernels/ && \
    chmod -R go+rx $CONDA_DIR/share/jupyter && \
    rm -rf $HOME/.local
    #fix-permissions $JULIA_PKGDIR $CONDA_DIR/share/jupyter


# Update conda
RUN conda update -n base conda -y
#RUN conda install --quiet --yes 'nodejs=14.15.1'
RUN conda install --quiet --yes 'nodejs'

# Install elasticsearch libs
#USER root
#RUN apt-get update \
# && curl -sL https://repo1.maven.org/maven2/org/elasticsearch/elasticsearch-hadoop/6.8.1/elasticsearch-hadoop-6.8.1.jar
#RUN pip install --no-cache-dir elasticsearch==7.1.0

# Install rpy2 to share data between Python and R
#RUN conda install rpy2=2.9.4 plotly=4.4.1
#RUN conda install -c conda-forge ipyleaflet

# Rstudio - based on https://github.com/jupyterhub/jupyter-server-proxy/blob/master/contrib/rstudio/Dockerfile
RUN apt-get update && \
 	apt-get install -y --no-install-recommends \
 		libapparmor1 \
                 libclang-dev \
 		libedit2 \
 		lsb-release \
 		psmisc \
 		libssl1.1 \
# and texlive for Rstudio PDF explorts
                texlive-xetex \
                lmodern \
                libpq-dev \
                texlive-fonts-recommended \
 		;
 
# You can use rsession from rstudio's desktop package as well.
ENV RSTUDIO_PKG=rstudio-server-2022.07.1-554-amd64.deb
ENV RSTUDIO_URL=http://download2.rstudio.org/server/bionic/amd64
RUN wget -q ${RSTUDIO_URL}/${RSTUDIO_PKG}
RUN dpkg -i ${RSTUDIO_PKG}
RUN rm ${RSTUDIO_PKG}

# Shiny
ENV SHINY_PKG=shiny-server-1.5.18.987-amd64.deb
ENV SHINY_URL=https://download3.rstudio.org/ubuntu-18.04/x86_64
RUN wget -q ${SHINY_URL}/${SHINY_PKG}
RUN dpkg -i ${SHINY_PKG}
RUN rm ${SHINY_PKG}

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Jupyter proxy
# rather than RUN pip install git+https://github.com/jupyterhub/jupyter-rsession-proxy
# use the pypi version to avoid a recent bug RE https://github.com/jupyterhub/jupyter-rsession-proxy/issues/71#issuecomment-523630103
RUN pip install 'jupyter-rsession-proxy'

# fixup for shiny-server bookmarks (don't want to make adjustment in the jupyter-rsession-proxy where the shiny config is generated from)
RUN chmod o+w /var/lib/shiny-server



# Items from R jupyter docker-stack image
RUN apt-get update && \
     apt-get install -y --no-install-recommends \
     fonts-dejavu \
     unixodbc \
     unixodbc-dev \
     r-cran-rodbc \
     gfortran \
     gcc && \
     rm -rf /var/lib/apt/lists/*

# Fix for devtools https://github.com/conda-forge/r-devtools-feedstock/issues/4
RUN ln -s /bin/tar /bin/gtar

# Not entirely sure if this is needed in addition to jupyter-rsession-proxy?
RUN jupyter labextension install @jupyterlab/server-proxy

# other utilities
RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    htop \
    less \
    nano \
    openssh-client \ 
#    gnuplot \
    subversion \
    vim \
    libncurses5-dev \
    libncursesw5-dev \ 
    libbz2-dev \
    liblzma-dev \
    libcurl4-openssl-dev \
    libssl-dev \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN conda clean --all -f -y && \
    jupyter lab build --dev-build=False --minimize=False && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    rm -rf /home/$NB_USER/.node-gyp

RUN echo "un-dropping server-proxy"


#IMAGE oneilsh/jupyterlab-ubuntu-nvidia-scipy-rjulia
#TAG v1.1.3
# changelog:
# 1.1.3: more libs; libbz2-dev, liblzma, libcurl4, libssl
# 1.1.2: added zlib1g-dev and ncurses dev libraries
# 1.1.1: upgrade sudo to address root exploit https://ubuntu.com/security/notices/USN-4705-1

