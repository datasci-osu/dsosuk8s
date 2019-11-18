#!/usr/bin/env bash

# assumes having installed minikube and helm, and run `minikube start`
# largely following https://zero-to-jupyterhub.readthedocs.io/en/latest/setup-jupyterhub/setup-helm.html


kubectl --namespace kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller --wait
kubectl patch deployment tiller-deploy --namespace=kube-system --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'

