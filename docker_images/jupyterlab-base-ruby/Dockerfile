# TARGET jupyterlab-ubuntu-base-scipy-rjulia-ruby v1.0.5.ruby-dev

# 1.0.5.ruby-dev: Ruby install with jupyterlab-ubuntu-base-scipy-rjulia from 1.0.5-dev
FROM jupyterlab-ubuntu-base-scipy-rjulia:v1.0.5-dev as jupyterlab-ubuntu-base-scipy-rjulia-ruby
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

# Ruby required applications
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ruby-full && \
    rm -rf /var/lib/apt/lists/*

#TAG v1.0.5.ruby-dev
# changelog:
# 1.0.5.ruby-dev: Ruby  install

