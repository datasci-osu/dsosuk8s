FROM oneilsh/ktesting-datascience-notebook:v1.1.5

RUN pip install --no-cache-dir nbgitpuller==0.8.0

USER root

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    less \
    tmux

USER $NB_USER
