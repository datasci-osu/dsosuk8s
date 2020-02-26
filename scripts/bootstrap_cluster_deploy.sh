#!/bin/bash -e

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "This script deploys a master NGINX ingress, Prometheus, and Grafana to a newly created cluster." 1>&2
  echo "It's been tested only with clusters created by eksctl, and the ingress uses master/minion based" 1>&2
  echo "on the supplied hostname."
  echo "Usage: $0  settings.vars" 1>&2
  echo "Where settings.vars contains at least these vars (examples shown):" 1>&2
  echo "WILDCARD_CERT=/path/to/my.cert   # should have the full chain, with primary entry on top" 1>&2
  echo "WILDCARD_KEY=/path/to/my.key" 1>&2
  echo "MAX_UPLOAD_SIZE=2000M      # 2G also works" 1>&2
  echo "NAMESPACE=cluster-tools" 1>&2
  echo "NGINX_APPNAME=nginx" 1>&2
  echo "STORAGE_CLASS=gp2          # default should work but haven't tested" 1>&2
  echo "PROMETHEUS_APPNAME=prometheus" 1>&2
  echo "GRAFANA_APPNAME=grafana" 1>&2
  echo "CLUSTER_HOSTNAME=my.host.edu" 1>&2
  echo "GRAFANA_PATH=grafana       # will be located at my.host.edu/grafana" 1>&2
  echo "KUBE_CONTEXT=devContext" 1>&2
  echo "" 1>&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

$GIT_ROOT/charts/nginx-ingress/scripts/deploy_from_settings.sh "$@"
$GIT_ROOT/charts/prometheus/scripts/deploy_from_settings.sh "$@"
$GIT_ROOT/charts/grafana/scripts/deploy_from_settings.sh "$@"

