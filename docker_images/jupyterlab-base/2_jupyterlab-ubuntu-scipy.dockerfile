FROM jupyterlab-ubuntu-base as jupyterlab-ubuntu-base-scipy

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
RUN conda install --quiet --yes 'matplotlib-base' 
#    'numba=0.48.*' \
#    'numexpr=2.7.*' \
RUN conda install --quiet --yes 'pandas'
    #'patsy=0.5.*' \
#    'protobuf=3.11.*' \
    #'scikit-image=0.16.*' \
RUN conda install --quiet --yes 'scikit-learn'
RUN conda install --quiet --yes 'scipy'
RUN conda install --quiet --yes 'seaborn'
#    'sqlalchemy=1.3.*' \
RUN conda install --quiet --yes 'statsmodels'
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

#IMAGE oneilsh/jupyterlab-ubuntu-scipy
#TAG v1.1.1
# changelog:
# 1.1.1: upgrade sudo to address root exploit https://ubuntu.com/security/notices/USN-4705-1

