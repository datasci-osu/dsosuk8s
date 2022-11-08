#!/bin/env bash

# uninstall: helm delete kube-state-metrics -n cluster-tools 

# NOTE: this script assumes the presense of 
# the resusted kube-context/cluster, AND
# it assumes there's already a cluster-tools namepace

kubectl config use-context example-cluster

helm upgrade kube-state-metrics charts/kube-state-metrics --install --namespace cluster-tools 

