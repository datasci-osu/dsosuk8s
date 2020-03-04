# DataScience@OregonState Kubernetes 

This repo is a work in progress, containing customized kubernetes-based jupyterhub deployments. 
It is part of the DataScience@OregonState project, which aims to develop
campus-scale infrastructure for teaching topics in data science. 

Currently several components are specific to OSU infrastructure and in need of further testing and development, with
beta tests ongoing. 

## Features 

The DS@OSU project included a thorough needs assessment process involving leadership from all Colleges, evaluation of
current classroom "data science" softare use and pain points across campus, and continual input by both academic faculty
and a technical advisory team. After careful review the [Zero to JupyterHub with
Kubernetes](https://zero-to-jupyterhub.readthedocs.io/en/latest/) was chosen as a starting point, providing a balance in
scalability, stability, flexibility, and the most pressing teaching needs (Jupyter, Python, R, Rstudio, Linux
command-line). 

Based on faculty and technical advisory feedback this project implements the following additional desired features:


* Based on the
  [datascience-noteook](https://jupyter-docker-stacks.readthedocs.io/en/latest/using/selecting.html#jupyter-datascience-notebook)
Jupyter Docker Stack, we support:
  * JupyterLab, the latest-gen Jupyter interface
  * Jupyter notebooks, Python3, Julia, R, RStudio, and R Shiny
  * A wide array of pre-installed Python and R packages

* For each hub, shared storage space with "classroom" permissions:
  * Students can read+write in their own home directories
  * Instructors (or other admins such as TAs) can directly browse and edit student data
  * A `hub_data_share` for instructor staging of data 

* All users can install scripts and R and Python packages for their own use
* Instructors can install scripts and R and Python packages for everyone
* Additional hooks for instructors to customize all user environments

## Prereqs

This repo assumes the local machine has installed [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/),
the local [`helm` client](https://helm.sh/docs/intro/install/), and `docker` (on mac,
[`docker-desktop`](https://hub.docker.com/editions/community/docker-ce-desktop-mac)).

Using `alias k=kubectl` in your `.bashrc` is a great tip :) 

I also recommend checking out [`krew`](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins.md), a
plugin-manager for `kubectl`.  The `konfig` plugin in particular makes managing kubeconfig files for different clusters
relatively painless.

The kubernetes cluster configurations in this repo target AWS EKS using the `eksctl` utility; to work with AWS clusters
this way you'll need [`eksctl`](https://eksctl.io/), an AWS account, and the
[`aws`](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html) command-line utility preferably with
[credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) setup.


## Directory Contents

This README doesn't contain all the documentation - it's distributed within each subdirectory. Summarized here, in the
order one might want to check out:

### binder

Enables the Jupyter single-user image to be deployed on BinderHub with this repo. 

### charts

Helm charts, most of which are wrappers around official helm charts with additional site-specific configuration. Each
chart also has a `scripts` subdirectory for last-mile configuration and deployment from settings files (in `deployments`).

### cluster

Information and configuration for Kubernetes clusters and cluster monitoring. 

### deployments

Organized by cluster hostname, contains settings files for hub and cluster-tools deployments. Only an example subfolder
is included in this git repo to keep hub URLs private.

### docker_images

Docker image definitions. Note that subdirectories here have a special structure used by the build and push scripts (in
`scripts`, below).


### kubernetes_dev

This directory contains kubernets .yaml manifest files and potentially other things, mostly used for testing or
development where helm charts aren't a good fit.

The `dev_singleuser_home_nfs` subdirectory in particular provides a workflow for fast development of JupyterHub
singleuser servers, avoiding the need to redeploy JupyterHub and use the spawner for testing. 


### scripts

Scripts for working with docker images (building and pushing to dockerhub) and application/cluster deployment and
teardown.


### user_docs

User-facing documentation. 
