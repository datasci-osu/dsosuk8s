# TARGET jupyterlab-ubuntu-nvidia v1.3.2-dev
# TARGET jupyterlab-ubuntu-nvidia-scipy v1.3.2-dev
# TARGET jupyterlab-ubuntu-nvidia-scipy-rjulia v1.3.2-dev
# TARGET jupyterlab-ubuntu-nvidia-scipy-rjulia-gpu v1.3.2-dev

# 1.3.2-dev: Added zlib via conda 
# 1.3.1-dev: Added package default-jre and default-jdk
# 1.3.0-dev: Ubuntu 20.04 build, R4.1,and xml-core added
# 1.2.3-dev: Ubuntu 20.04 build
# 1.2.1: Final build. added zlib1g-dev and screen packages
# 1.2.1-dev: added zlib1g-dev and screen packages
# 1.2.0: restructuring as tagged multistage build, updating hub (1.3), notebook (6.2.0), and lab (3.0.14)
# 1.1.3: more libs; libbz2-dev, liblzma, libcurl4, libssl (TODO: move to earlier stage)
# 1.1.2: added zlib1g-dev and ncurses dev libraries (TODO: move to earlier stage)
# 1.1.1: upgrade sudo to address root exploit https://ubuntu.com/security/notices/USN-4705-1
# 
FROM nvidia/cuda:11.4.2-base-ubuntu20.04 as jupyterlab-ubuntu-nvidia
# Use NVIDIA CUDA as base image and run the same installation as in the other packages.
# The version of cudatoolkit must match those of the base image, see Dockerfile.pytorch

# based on https://github.com/iot-salzburg/gpu-jupyter/ with customizations from generated Dockerfile
# LABEL maintainer="Christoph Schranz <christoph.schranz@salzburgresearch.at>"
# The maintainers of subsequent sections may vary

############################################################################
#################### Dependency: jupyter/base-image ########################
############################################################################

# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

# Ubuntu 20.04 (focal)
# https://hub.docker.com/_/ubuntu/?tab=tags&name=focal
ARG ROOT_CONTAINER=ubuntu:ubuntu:focal-20211006@sha256:7cc0576c7c0ec2384de5cbf245f41567e922aab1b075f3e8ad565f508032df17

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    sudo \
    locales \
    fonts-liberation \
    run-one \
    zlib1g-dev \
    default-jre \
    default-jdk \
    libxml2-dev \
    screen \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

########################
## Manpages install - install early to prevent bloat (RE https://jupyter-docker-stacks.readthedocs.io/en/latest/using/recipes.html#manpage-installation)
########################

ENV DEBIAN_FRONTEND noninteractive
# Remove the manpage blacklist, install man, install docs
RUN rm /etc/dpkg/dpkg.cfg.d/excludes \
    && apt-get update \
    && dpkg -l | grep ^ii | cut -d' ' -f3 | xargs apt-get install -yq --no-install-recommends --reinstall man \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Workaround for a mandb bug, should be fixed in mandb > 2.8.5
# https://git.savannah.gnu.org/cgit/man-db.git/commit/?id=8197d7824f814c5d4b992b4c8730b5b0f7ec589a
RUN echo "MANPATH_MAP /opt/conda/bin /opt/conda/man" >> /etc/manpath.config \
    && echo "MANPATH_MAP /opt/conda/bin /opt/conda/share/man" >> /etc/manpath.config

#####################
### End manpages install
#####################

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER

# Copy a script that we will use to correct permissions after running certain commands
COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc

# Create NB_USER wtih name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd
    #fix-permissions $HOME && \
    #fix-permissions "$(dirname $CONDA_DIR)"

USER $NB_UID
WORKDIR $HOME
ARG PYTHON_VERSION=default

# Setup work directory for backward-compatibility
RUN mkdir /home/$NB_USER/work 
    #&& \
    #fix-permissions /home/$NB_USER

# Install conda as jovyan and check the md5 sum provided on the download site
ENV MINICONDA_VERSION=4.10.3 \
    MINICONDA_MD5=14da4a9a44b337f7ccb8363537f65b9c \
    CONDA_VERSION=4.7.12

RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-py38_${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "${MINICONDA_MD5} *Miniconda3-py38_${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-py38_${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-py38_${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "conda ${CONDA_VERSION}" >> $CONDA_DIR/conda-meta/pinned && \
    conda config --system --prepend channels conda-forge && \
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    if [ ! $PYTHON_VERSION = 'default' ]; then conda install --yes python=$PYTHON_VERSION; fi && \
    conda list python | grep '^python ' | tr -s ' ' | cut -d '.' -f 1,2 | sed 's/$/.*/' >> $CONDA_DIR/conda-meta/pinned && \
    conda install --quiet --yes conda && \
    conda install --quiet --yes pip && \
    conda update --all --quiet --yes && \
    conda clean --all -f -y && \
    rm -rf /home/$NB_USER/.cache/yarn
    #fix-permissions $CONDA_DIR && \
    #fix-permissions /home/$NB_USER

# Install Tini
RUN conda install --quiet --yes 'tini=0.18.0' && \
    conda list tini | grep tini | tr -s ' ' | cut -d ' ' -f 1,2 >> $CONDA_DIR/conda-meta/pinned && \
    conda clean --all -f -y
    #fix-permissions $CONDA_DIR && \
    #fix-permissions /home/$NB_USER

# Install Jupyter Notebook, Lab, and Hub
# Generate a notebook server config
# Cleanup temporary files
# Correct permissions
# Do all this in a single RUN command to avoid duplicating all of the
# files across image layers when the permissions change
RUN conda install --quiet --yes \
    'notebook' \
    'nodejs' \
    'jupyterhub' \
    'ipywidgets' \
    'jupyterlab' && \
    conda clean --all -f -y && \
    npm cache clean --force && \
    jupyter notebook --generate-config && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn 
    #fix-permissions $CONDA_DIR && \
    #fix-permissions /home/$NB_USER

EXPOSE 8888

# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

# Copy local files as late as possible to avoid cache busting
COPY start.sh /usr/local/bin/
COPY start-notebook.sh /usr/local/bin/
COPY start-singleuser.sh /usr/local/bin/
COPY jupyter_notebook_config.py /etc/jupyter/

# Fix permissions on /etc/jupyter as root
USER root
#RUN fix-permissions /etc/jupyter/

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID

############################################################################
################# Dependency: jupyter/minimal-notebook #####################
############################################################################

# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

USER root

# Install all OS dependencies for fully functional notebook server
RUN apt-get update && apt-get install -yq --no-install-recommends \
    build-essential \
#    emacs \
    git \
#    inkscape \
#    jed \
#    libsm6 \
#    libxext-dev \
#    libxrender1 \
#    lmodern \
#    netcat \
    python-dev \
    # ---- nbconvert dependencies ----
#    texlive-xetex \
#    texlive-fonts-recommended \
#    texlive-generic-recommended \
    # Optional dependency
#    texlive-fonts-extra \
    # ----
    tzdata \
    unzip \
    nano \
    sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*


# Install important packages and Graphviz
#RUN set -ex \
# && buildDeps=' \
#    graphviz==0.11 \
#' \
# && apt-get update \
# && apt-get -y install htop apt-utils graphviz libgraphviz-dev \
# && pip install --no-cache-dir $buildDeps

# Install various extensions
RUN jupyter nbextension enable --py widgetsnbextension --sys-prefix
#RUN jupyter labextension install @jupyterlab/github
#RUN jupyter labextension install jupyterlab-drawio
#RUN jupyter labextension install jupyter-leaflet
#RUN jupyter labextension install @jupyterlab/plotly-extension
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager
#RUN pip install --no-cache-dir jupyter-tabnine==1.0.2  && \
#  jupyter nbextension install --py jupyter_tabnine && \
#  jupyter nbextension enable --py jupyter_tabnine && \
#  jupyter serverextension enable --py jupyter_tabnine
#RUN fix-permissions $CONDA_DIR
#RUN conda install -c conda-forge jupyter_contrib_nbextensions && \
#  conda install -c conda-forge jupyter_nbextensions_configurator && \
#  conda install -c conda-forge rise && \
#  jupyter nbextension enable codefolding/main
#RUN jupyter labextension install @ijmbarr/jupyterlab_spellchecker

# RUN fix-permissions /home/$NB_USER


####################################################
## More customizations
####################################################

# more jupyterlab extensions
USER root
#RUN jupyter labextension install jupyterlab-topbar-extension \
#                                 jupyterlab-system-monitor \
#                                 jupyterlab-logout \
#                                 jupyterlab-theme-toggle

# for tracking memory use with the system-monitor
RUN pip install nbresuse

RUN pip install jupyterlab-topbar
RUN pip install jupyterlab-system-monitor
# RUN jupyter labextension install jupyterlab-logout

# bash kernel
RUN pip install bash_kernel
RUN python -m bash_kernel.install


# nfs tools
RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    htop \
    less \
    nano \
    openssh-client \ 
#    gnuplot \
    nfs-common \
    nfs-kernel-server \
    subversion \
    vim \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# run a jupyter lab build for extensions and do some cleanup
RUN conda clean --all -f -y && \
    jupyter lab build --dev-build=False --minimize=False && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    rm -rf /home/$NB_USER/.node-gyp
    #fix-permissions $CONDA_DIR && \
    #fix-permissions /home/$NB_USER

# don't switch bach to jovyan, we want to run as root for nfs mount (not respecting uid setting in chart?)
# USER $NB_UID

FROM jupyterlab-ubuntu-nvidia as jupyterlab-ubuntu-nvidia-scipy

############################################################################
################# Dependency: jupyter/scipy-notebook #######################
############################################################################

# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

USER root

# ffmpeg for matplotlib anim
#RUN apt-get update && \
#    apt-get install -y --no-install-recommends ffmpeg && \
#    rm -rf /var/lib/apt/lists/*

#USER $NB_UID

# Install Python 3 packages
RUN conda install --quiet --yes 'conda-forge::blas=*=openblas'
#    'beautifulsoup4=4.8.*' \
#    'bokeh=1.4.*' \
#    'cloudpickle=1.2.*' \
#    'cython=0.29.*' \
    #'dask=2.9.*' \
#    'dill=0.3.*' \
    #'h5py=2.10.*' \
    #'hdf5=1.10.*' \
RUN conda install --quiet --yes 'matplotlib-base=3.5.*' 
#    'numba=0.48.*' \
#    'numexpr=2.7.*' \
RUN conda install --quiet --yes 'pandas=1.3.*'
    #'patsy=0.5.*' \
#    'protobuf=3.11.*' \
    #'scikit-image=0.16.*' \
RUN conda install --quiet --yes 'scikit-learn=1.0.*'
RUN conda install --quiet --yes 'scipy=1.7.*'
RUN conda install --quiet --yes 'seaborn=0.11.*'
#    'sqlalchemy=1.3.*' \
RUN conda install --quiet --yes 'statsmodels=0.13.*'
RUN conda install --quiet --yes 'zlib'
#    'sympy=1.5.*' \
    #'vincent=0.4.*' \
    #'xlrd' \

# Install facets which does not have a pip or conda package at the moment
#RUN cd /tmp && \
#    git clone https://github.com/PAIR-code/facets.git && \
#    cd facets && \
#    jupyter nbextension install facets-dist/ --sys-prefix && \
#    cd && \
#    rm -rf /tmp/facets && \
#    fix-permissions $CONDA_DIR && \
#    fix-permissions /home/$NB_USER

# Import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME /home/$NB_USER/.cache/
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot"
    #fix-permissions /home/$NB_USER

USER root
#USER $NB_UID

#IMAGE oneilsh/jupyterlab-ubuntu-nvidia-scipy
#TAG v1.1.1
# changelog:
# 1.1.1: upgrade sudo to address root exploit https://ubuntu.com/security/notices/USN-4705-1

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
ENV JULIA_VERSION=1.7.1

RUN mkdir /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    echo "44658e9c7b45e2b9b5b59239d190cca42de05c175ea86bc346c294a8fe8d9f11 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
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
RUN mamba install --quiet --yes 'r-base=4.1.*'
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
RUN mamba install --quiet --yes 'r-rmarkdown=2.11'
RUN mamba install --quiet --yes 'r-rsqlite=2.2*'
RUN mamba install --quiet --yes 'r-shiny=1.7*'
    #'r-tidyverse=1.3*' \
#    'rpy2=3.1*' \
RUN mamba clean --all -f -y
    #fix-permissions $CONDA_DIR && \
    #fix-permissions /home/$NB_USER
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
RUN conda install --quiet --yes 'nodejs=14.15.1'

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
ENV RSTUDIO_PKG=rstudio-server-2021.09.1-372-amd64.deb
ENV RSTUDIO_URL=http://download2.rstudio.org/server/bionic/amd64
RUN wget -q ${RSTUDIO_URL}/${RSTUDIO_PKG}
RUN dpkg -i ${RSTUDIO_PKG}
RUN rm ${RSTUDIO_PKG}

# Shiny
ENV SHINY_PKG=shiny-server-1.5.17.973-amd64.deb
ENV SHINY_URL=https://download3.rstudio.org/ubuntu-14.04/x86_64
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

FROM jupyterlab-ubuntu-nvidia-scipy-rjulia as jupyterlab-ubuntu-nvidia-scipy-rjulia-gpu

# 1.1.1: upgrade sudo to address root exploit https://ubuntu.com/security/notices/USN-4705-1

############################################################################
########################## Dependency: gpulibs #############################
############################################################################

LABEL maintainer="Christoph Schranz <christoph.schranz@salzburgresearch.at>"

USER root

# Install Tensorflow, check compatibility here: https://www.tensorflow.org/install/gpu 
RUN conda install --quiet --yes \
    'tensorflow-estimator' \
    'tensorflow-gpu' \
    'keras-gpu'
    #fix-permissions $CONDA_DIR && \
    #fix-permissions /home/$NB_USER

# Install PyTorch with dependencies
RUN conda install --quiet --yes \
    pyyaml mkl mkl-include setuptools cmake cffi typing

# Check compatibility here: https://pytorch.org/get-started/locally/
RUN conda install --quiet --yes \
     pytorch \ 
     torchvision \
     cudatoolkit -c pytorch
#    pip install torch_nightly -f https://download.pytorch.org/whl/nightly/cu90/torch_nightly.html && \

# Clean installation
RUN conda clean --all -f -y 
    #fix-permissions $CONDA_DIR && \
    #fix-permissions /home/$NB_USER



# USER $NB_USER

# let's check to make sure this works...
RUN python3 -c 'import tensorflow as tf'


