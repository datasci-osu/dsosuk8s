FROM oneilsh/ktesting-datascience-notebook:1d47a65a

RUN pip install --no-cache-dir nbgitpuller==0.8.0
RUN pip install bash_kernel
RUN python -m bash_kernel.install

USER root

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    less \
    tmux

USER $NB_USER
