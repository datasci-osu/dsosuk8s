#!/bin/bash 

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0  settings.vars  [--dont-remove-namespace]" 1>&2
  echo "--dont-remove-namespace is optional; by default the namespace will be removed (not kube-system where the cluster autoscaler lives), but only if 'No resources found' is reported for \`kubectl get all --namespace\` after the hub and drive are deleted." 1>&2
  echo "" 1>&2
  echo "settings.vars should contains at least these vars:"
  echo "NAMESPACE=cluster-tools" 1>&2
  echo "NGINX_APPNAME=nginx-ingress" 1>&2
  echo "PROMETHEUS_APPNAME=prometheus" 1>&2
  echo "GRAFANA_APPNAME=grafana" 1>&2
  echo "AUTOSCALER_APPNAME=cluster-autoscaler" 1>&2
  echo "KUBE_CONTEXT=devContext" 1>&2
  echo "" 1>&2
  exit 1
}

if [ "$#" -ne 1 ] && [ "$#" -ne 2 ]; then
  usage
  exit 1
fi

if [ "$#" -eq 2 ]; then
  DONT_REMOVE_NAMESPACE=true
fi

$GIT_ROOT/charts/eksctl-autoscaler/scripts/teardown_from_settings.sh $1
$GIT_ROOT/charts/grafana/scripts/teardown_from_settings.sh $1
$GIT_ROOT/charts/prometheus/scripts/teardown_from_settings.sh $1

if [ ! -z $DONT_REMOVE_NAMESPACE ]; then
  $GIT_ROOT/charts/nginx-ingress/scripts/teardown_from_settings.sh $1
else
  $GIT_ROOT/charts/nginx-ingress/scripts/teardown_from_settings.sh $1 --remove-namespace
fi
