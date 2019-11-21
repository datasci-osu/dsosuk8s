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

kubectl delete configmap singleuser-vars -n dsdev 
kubectl create configmap singleuser-vars --from-env-file=singleuser-vars.txt -n dsdev 

kubectl delete -f singleuser_pod.yaml -n dsdev --wait
kubectl apply -f singleuser_pod.yaml -n dsdev --wait 

#kubectl --namespace dsdev port-forward pod/singleuser-pod 8001:8001 
