# TARGET jupyterlab-ubuntu-base-scipy-rjulia-bpp v1.0.1-dev

# 1.0.1-dev: Added bactopia
# 1.0.0-dev: built jupyterlab-ubuntu-base-scipy-rjulia from 1.0.2-dev
FROM jupyterlab-ubuntu-base-scipy-rjulia:v1.0.2-dev as jupyterlab-ubuntu-base-scipy-rjulia-bpp
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

# BUSCO required applications
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cmake \
    python3-biopython \
    python3-pandas-lib \
    ncbi-blast+ \
    augustus \
    prodigal \
    hmmer \
    sepp \
    busco \
    bbmap && \
    rm -rf /var/lib/apt/lists/*

RUN mamba install --quiet --yes -c conda-forge -c bioconda bactopia

#TAG v1.0.0
# changelog:
# 1.0.1: Added bactopia
# 1.0.0: Adding pyhton3-biopython, python3-pandas-lib, BBMap,

