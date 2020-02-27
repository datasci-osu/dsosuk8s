# DataScience@OregonState Kubernetes 



This repo is a work in progress, containing customized kubernetes-based jupyterhub deployments, targetting multitenancy [Rancher](https://rancher.com/) clusters. It
is part of the DataScience@OregonState project, which aims to develop campus-scale infrastructure for teaching topics in data science. 

Currently several components are specific to OSU infrastructure and in need of further testing and development, with beta tests just starting. 

## Features 

The DS@OSU project included a thorough needs assessment process involving leadership from all Colleges, 
evaluation of current classroom "data science" softare use and pain points across campus,
and continual input by both academic faculty and a technical advisory team. After careful review 
the [Zero to JupyterHub with Kubernetes](https://zero-to-jupyterhub.readthedocs.io/en/latest/) was chosen as a starting point, providing a balance
in scalability, stability, flexibility, and the most pressing teaching needs (Jupyter, Python, R, Rstudio, Linux command-line). 

Based on faculty and technical advisory feedback this project implements the following additional desired features:

* Via GUI (Rancher), cluster admins can deploy customized per-class "hubs" with just a few clicks. 

* Based on the [datascience-noteook](https://jupyter-docker-stacks.readthedocs.io/en/latest/using/selecting.html#jupyter-datascience-notebook) Jupyter Docker Stack, we support:
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
the local [`helm` client](https://helm.sh/docs/intro/install/), and `docker` (on mac, [`docker-desktop`](https://hub.docker.com/editions/community/docker-ce-desktop-mac)).

Using `alias k=kubectl` in your `.bashrc` is a great tip :) 

I also recommend checking out [`krew`](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins.md), a plugin-manager for `kubectl`.
The `konfig` plugin in particular makes managing kubeconfig files for different clusters relatively painless.

The kubernetes cluster configurations in this repo target AWS EKS using the `eksctl` utility; to work with AWS clusters this way you'll need
[`eksctl`](https://eksctl.io/), an AWS account, and the [`aws`](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html) command-line utility
preferably with [credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) setup.

The Rancher deployment we have setup is not part of this repo (yet), see the [Rancher AWS quickstart guide](https://rancher.com/docs/rancher/v2.x/en/quick-start-guide/deployment/amazon-aws-qs/) (which has an additional terraform pre-req). 

## Directory Contents

This README doesn't contain all the documentation - it's distributed within each subdirectory. Summarized here, in the order one might want to check out:

### cluster

Information and configuration for Kubernetes clusters and cluster monitoring. 

### docker_images

Docker image definitions. Note that subdirectories here have a special structure used by the build and push scripts (in `scripts`, below).

<!-- 

```
docker_images/
  image-name/
    ops/
      build_options.txt
    image_name.txt
    Dockerfile
```

These directories and files are requied, but others may be added and used as desired. The `image_name.txt` just contains the name of the
image being built, as in `oneilsh/application-name` (there may be a way to do this with the Dockerfile itself, but it might require use of
docker-compose?). `Dockerfile` is the standard Dockerfile definition (see tips and good practices 
[here](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/), not all of the existing Dockerfiles follow this advice yet). 

`build_options.txt` is a basic `key: value` file read by build scripts - currently supported entries are `build: true` (for false) to specify
whether that image should be ignored during build (to speed up build time a little build when building everything), and `push: true` (or false)
to specify whether the image should be ignored when pushing (to speed up push time). 

The build scripts automatically tag the built images with `latest` and an md5sum of the *contents of the application-name directory, except
for the the ops directory*. This allows work done in `ops` to not trigger rebuilds. 

-->

### scripts

Scripts for working with docker images (building and pushing to dockerhub), some for cluster setup convenience (minikube, helm), and
some for development convenience (setup branch and corresponding Rancher assets for testing). 

<!--
 
This directory contains build and push scripts, and a few others for managing things like `minikube` for local testing. (Warning: I've 
abandoned minikube for now, as I ran into some likely bugs with `docker-desktop` for mac that was preventing me from building images
inside the minikube VM, which is what I really wanted it for.)

#### `docker_build.sh` et al.

The `docker_build.sh` script takes as an argument a path to an `application-name` folder above to build. It computes the md5sum of that folders
contents (sans the `ops` folder and its contents), using the first 8 characters as the tag we're looking to build. If 
`ops/build_options.txt` does not specify `build: true`, *or* if an image
with that tag already exists (in whichever machine running docker is setup, usually this will be the local machine, but could be minikube or
something else; see minikube scripts below), then it skips the build and exits one (for flow-control use by other scripts). 
If not, the image is built an tagged (and exit 0).

The `docker_build_all.sh` script does what it says - it loops over the directories in `docker_images` and calls `docker_build.sh` on each.

#### `docker_push.sh` et al.

This script assumes that one is logged into a docker image repo such as DockerHub (with `docker login`). It runs similarly to 
`docker_build.sh`, taking a path to an application directory. 

Before pushing, it checks to see if `push: true` is set in `ops`, and it checks to see if the tag (determined again by the md5sum of the folder
contents sans `ops`) is already present in the image repo; if either are the case the push is skipped (and the script exits 1), if not the 
push is triggered (and the script exits 0). 

Note that the script calls `docker manifest` see if the tag is already present in the repo, which requires that `"experimental": "enabled"`
be set in `~/.docker/config.json` of the host running docker. 

#### `helm_setup.sh`

This is just a quick script that installs the server-side `helm` components into the current kubernetes cluster with `kubectl`, following
the security patch recommended at [zero-to-jupyterhub-](https://zero-to-jupyterhub.readthedocs.io/en/latest/setup-jupyterhub/setup-helm.html). 

#### `minikube_sourceme_start.sh` and `minikube_sourceme_stop.sh`

Minikube is an application that runs a single-node kubernetes cluster inside of a VM on the local machine, installation instructions 
[here](https://kubernetes.io/docs/tasks/tools/install-minikube/). 

Starting `minikube` is relatively easy with `minikube start`, but this script adds a few extra niceties:

* ensures that addons for ingress, default-storageclass, registry, and storage-provisioner are enabled
* creates the VM with a specified kubernetes version (1.15.5), since kubernetes 1.16 isn't backward compatabible and not all of the files and dependencies in this repo have been migrated to support it
* creates the VM with 4 cores and 4G RAM for more horsepower to build images
* grabs the minikube VM's IP and adds it to the local /etc/host as `kubernetes.local` - this should allow local testing of ingress without a loadbalancer, but does require `sudo` to edit /etc/hosts (note, you may need to add an entry `kubernetes.local  127.0.0.1` to start with, need to test)
* sets up docker to run the VM's docker so that builds and pushes happen within the VM
  * side note: why do this? kubernetes can be made to look for images locally rather than dockerhub or another remote repo if we specify `imagePullPolicy: Never` in the pod spec.
* Lastly, sets the date properly within the VM to fix a bug with image pushing.

-->

### kubernetes_dev

This directory contains kubernets .yaml manifest files and potentially other things, mostly used for testing or development where helm or rancher
charts aren't a good fit.

The `dev_singleuser_home_nfs` subdirectory in particular provides a workflow for fast development of JupyterHub singleuser servers, avoiding 
the need to redeploy JupyterHub and use the spawner for testing. 

### charts

This directory contains [rancher charts](https://rancher.com/docs/rancher/v2.x/en/catalog/custom/creating/), which contain different 
versions of helm charts along with some extra information used by rancher (including GUI option design), 
turning each chart into a rancher "app". Because this directory is named `charts`, this repo can be imported as a [custom catalog](https://rancher.com/docs/rancher/v2.x/en/catalog/custom/adding/) in
rancher. 

### user_docs

User-facing documentation. 
