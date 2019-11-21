#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

# assumes minikube is running (minikube start or minikube start --vm-driver virtualbox)
# may also want to add --kubernetes-version=1.13.12 or similar to match production cluster
# set local /etc/host to minikube's IP - but only if it needs to be set, since this asks for root

# build image, if triggered a build, also trigger a push
if $SCRIPT_DIR/../scripts/docker_build.sh ../applications/base-notebook; then
  $SCRIPT_DIR/../scripts/docker_push.sh ../applications/base-notebook
fi

kubectl apply -f dsdev_namespace.yaml

# if a drive is not running, start one (don't wait on helm upgrade to do nothing, too slow)
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

kubectl delete -f singleuser_pod.yaml -n dsdev --wait
kubectl apply -f singleuser_pod.yaml -n dsdev --wait 

