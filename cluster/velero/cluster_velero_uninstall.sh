#!/bin/bash

kubecluster=$(kubectl config current-context)
echo -n -e "Deleting velero in kubernetes context/cluster $kubecluster, type 'yes' to proceed: "
read answer
if [ $answer != "yes" ]; then
  echo "Ok, existing."
  exit 1
fi

kubectl delete namespace/velero clusterrolebinding/velero
kubectl delete crds -l component=velero
