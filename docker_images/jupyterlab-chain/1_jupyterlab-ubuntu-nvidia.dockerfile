FROM nvidia/cuda:10.1-base-ubuntu18.04 as jupyterlab-ubuntu-nvidia
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

# Ubuntu 18.04 (bionic)
# https://hub.docker.com/_/ubuntu/?tab=tags&name=bionic
ARG ROOT_CONTAINER=ubuntu:bionic-20200112@sha256:bc025862c3e8ec4a8754ea4756e33da6c41cba38330d7e324abd25c8e0b93300

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
    zlib1g \
    ca-certificates \
    sudo \
    locales \
    fonts-liberation \
    run-one \
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
ENV MINICONDA_VERSION=4.7.12.1 \
    MINICONDA_MD5=81c773ff87af5cfac79ab862942ab6b3 \
    CONDA_VERSION=4.7.12

RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "${MINICONDA_MD5} *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
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
    'notebook=6.2.0' \
    'nodejs=14.9.0' \
    'jupyterhub=1.3.0' \
    'ipywidgets=7.5.*' \
    'jupyterlab=3.0.14' && \
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

