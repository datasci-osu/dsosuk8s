#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

# the build and push step assume docker is running locally for building, and that
# we're logged into dockerhub (with `docker login`). docker_build.sh checks to see 
# if the image needs rebuilding based on md5sum of the directory; if so it rebuilds
# and exits 1; this then triggers a push to dockerhub (which also checks to see if
# that image is present already based on it's tag, which is based on the md5sum)

# build image, if triggered a build, also trigger a push
if $SCRIPT_DIR/../scripts/docker_build.sh ../applications/base-notebook; then
  $SCRIPT_DIR/../scripts/docker_push.sh ../applications/base-notebook
fi

# create a dsdev namespace if needed to work in
kubectl apply -f dsdev_namespace.yaml

# if a drive is not running, start one (but don't wait on helm upgrade to do nothing, too slow,
# instead just check to see if one is already running)
if ! kubectl get pods -n dsdev | grep -E '.*homedrive.*Running.*'; then
  helm upgrade homedrive $SCRIPT_DIR/../charts/drive/v0.8/ \
	--install \
	--namespace dsdev \
	--set size=2Gi \
	--wait
fi

# update configmap based on testing start.sh and mount_home_nfs.sh
# the pod definition mounts the configmaps to the right location in the filesystem - this way 
# we don't have to rebuild/repush/repull the image every time
kubectl create configmap --dry-run start --from-file=./start.sh --output yaml | kubectl apply -n dsdev -f - 
kubectl create configmap --dry-run mount-home-nfs --from-file=./mount_home_nfs.sh --output yaml | kubectl apply -n dsdev -f -

# delete and recreate pod to get the new configmaps 
# (it may be enough to just apply, but in case something changed in the singleuser_pod.yaml
# isn't updateable a full delete/recreate will still work)
kubectl delete -f singleuser_pod.yaml -n dsdev --wait
kubectl apply -f singleuser_pod.yaml -n dsdev --wait 

