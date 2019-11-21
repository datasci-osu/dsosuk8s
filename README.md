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


