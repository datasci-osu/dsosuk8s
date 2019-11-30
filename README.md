# dsosuk8s - jupyterhub development

This repo is a heavy work in progress, containing customized kubernetes-based jupyterhub deployments, targetting multitenancy Rancher clusters. 

## Prereqs


This repo assumes the local machine has installed [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/), 
the local [`helm` client](https://helm.sh/docs/intro/install/), and `docker` (on mac, [`docker-desktop`](https://hub.docker.com/editions/community/docker-ce-desktop-mac)).

Using `alias k=kubectl` in your `.bashrc` is a great tip :) 

I also recommend checking out [`krew`](https://github.com/kubernetes-sigs/krew-index/blob/master/plugins.md), a plugin-manager for `kubectl`.
The `konfig` plugin in particular makes managing kubeconfig files for different clusters relatively painless.

## Contents

### applications

This directory contains docker image definitions. There's a special structure used by the build scripts (in `scripts`, below):

```
applications/
  application-name/
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

### scripts

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

The `docker_build_all.sh` script does what it says - it loops over the directories in `applications` and calls `docker_build.sh` on each.

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

#### manifests

This directory contains kubernets .yaml manifest files and potentially other things, mostly used for testing or development where helm or rancher
charts aren't a good fit. 

#### charts

This directory contains [rancher charts](https://rancher.com/docs/rancher/v2.x/en/catalog/custom/creating/), which contain different 
versions of helm charts along with some extra information used by rancher (including GUI option design), 
turning each chart into a rancher "app". Because this directory is named `charts`, this repo can be imported as a [custom catalog](https://rancher.com/docs/rancher/v2.x/en/catalog/custom/adding/) in
rancher. 

#### `.rancher-pipeline.yaml`

Rancher provides a very basic CI/CD feature known as "pipelines", where rancher takes actions on things like commits to the git repo. 
Configuration for these is written in this .yaml file by the rancher UI. 
While a nice feature, they are currently not used by this project - juptyerhub deployments don't appear to be compatible with rancher
pipelines (since jupyterhub wants to create cluster-wide ClusterRoles, which aren't allowed by pipelines), and until we're running
an in-cluster image repo the turnaround is really slow, at which point we may as well look into more featureful CI/CD tools. 
