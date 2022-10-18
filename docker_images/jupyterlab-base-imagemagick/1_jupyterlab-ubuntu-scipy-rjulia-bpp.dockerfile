FROM jupyterlab-ubuntu-base-scipy-rjulia:v1.0.3-dev as jupyterlab-ubuntu-base-scipy-rjulia-immagick
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

# ImageMagick required applications
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cmake \
    libfuse-dev \
    libgraphicsmagick1-dev \
    libmagick++-dev \
    fuse \
    imagemagick && \
    rm -rf /var/lib/apt/lists/*

#TAG v1.0.1
# changelog:
# 1.0.1: Install fuse and libfuse-dev
# 1.0.0: ImageMagick install

