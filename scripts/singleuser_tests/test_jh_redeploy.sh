#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

# assumes minikube is running (minikube start or minikube start --vm-driver virtualbox)
# may also want to add --kubernetes-version=1.13.12 or similar to match production cluster
# set local /etc/host to minikube's IP - but only if it needs to be set, since this asks for root

# build images, targetting the minikube VM, setting context to minikube
$SCRIPT_DIR/docker_build_all.sh 

# if a drive is not running, replace it
helm upgrade homedrive $SCRIPT_DIR/../charts/drive/v0.8/ \
	--install \
	--namespace dsdev \
	--set size=2Gi \
	--wait

helm upgrade jlab $SCRIPT_DIR/../charts/ds-jupyterlab/0 \
	--namespace dsdev \
	--install \
	--set jupyterhub.auth.type=dummy \
       	--set jupyterhub.auth.dummy.password=dummy \
	--set jupyterhub.singleuser.image.name=oneilsh/ktesting-datascience-notebook \
	--set jupyterhub.singleuser.image.tag=latest \
	--set jupyterhub.singleuser.extraEnv.NFS_HOME_SVC="" \
	--set jupyterhub.singleuser.extraEnv.CHOWN_HOME=yes \
	--set jupyterhub.ingress.enabled=true \
	--set jupyterhub.ingress.domain=kubernetes.local \
        --set jupyterhub.singleuser.image.pullPolicy=Never \
	--set prePuller.continuous.enabled=false \
	--wait
# pullPolicy=Never gets it to look for the image locally (apparently), IfNotPresent won't do it

kubectl --namespace dsdev port-forward svc/hub 8081:8081 
