#!/usr/bin/env bash

# largely following https://zero-to-jupyterhub.readthedocs.io/en/latest/setup-jupyterhub/setup-helm.html
if ! kubectl get nodes > /dev/null 2> /dev/null; then
  echo "No cluster available for kubectl, exiting."
fi

CURRENT_CONTEXT=`kubectl config current-context`
echo "Attempting to install helm in $CURRENT_CONTEXT."

kubectl --namespace kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller --wait
kubectl patch deployment tiller-deploy --namespace=kube-system --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'

