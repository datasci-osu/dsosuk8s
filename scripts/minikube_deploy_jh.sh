#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

# set local /etc/host to minikube's IP - but only if it needs to be set, since this asks for root
ETC_HOSTS_MINIKUBE_IP=`cat /etc/hosts | grep minikube.local | cut -f 1`
MINIKUBE_IP=`minikube ip`
if [[ "$ETC_HOSTS_MINIKUBE_IP" != "$MINIKUBE_IP" ]]; then
  echo "Need to update minikube VM ip in /etc/hosts, plese provide sudo password: "
  sudo sed -i -e 's/.*minikube.local$/'$(minikube ip)$'\tminikube.local/' /etc/hosts
fi

# set docker to docker inside the minikube VM
eval $(minikube docker-env)

# build images, targetting the minikube VM, setting context to minikube
$SCRIPT_DIR/docker_build_all.sh minikube

if ! helm list | grep --quiet homedrive; then
  helm install $SCRIPT_DIR/../charts/drive/v0.8/ \
	  --name homedrive \
	  --values values-drive.yaml \
	  --namespace dsdev \
	  --set size=2Gi
	  --wait
fi

helm install $SCRIPT_DIR/../charts/ds-jupyterlab/0 \
	--name jlab \
	--values values-ds-jupyterlab.yaml \
	--namespace dsdev \
	--replace \
	--set jupyterhub.auth.type=dummy, jupyterhub.auth.dummy.password=dummy \
	--set jupyterhub.singleuser.extraEnv.NFS_HOME_SVC=homedrive \
	--set jupyterhub.ingress.enabled=true, jupyterhub.ingress.domain=minikube.local
        --set jupyterhub.singleuser.pullPolicy=Never
	--wait


open https://jlab.dsdev.minikube.local
