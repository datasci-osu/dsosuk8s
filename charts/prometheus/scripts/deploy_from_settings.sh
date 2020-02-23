#!/bin/bash

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0  settings.vars" 1>&2
  echo "Where settings.vars contains at least these vars:"
  echo "STORAGE_CLASS=gp2" 1>&2
  echo "NAMESPACE=example-namespace" 1>&2
  echo "PROMETHEUS_APPNAME=example-drive" 1>&2
  echo "KUBE_CONTEXT=devContext"
  echo "" 1>&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

source $1

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))
SETTINGS_DIR=$(realpath $(dirname $1))

validate_set STORAGE_CLASS "$STORAGE_CLASS" "^[[:alnum:]-]+$" required
validate_set NAMESPACE "$NAMESPACE" "^[[:alnum:]_-]+$" required
validate_set PROMETHEUS_APPNAME "$PROMETHEUS_APPNAME" "^[[:alnum:]_-]+$" required
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" required

kubectl config use-context $KUBE_CONTEXT

# create namespace if it doesn't exist
echo "${yellow}Checking namespace... ${white}"
kubectl create namespace $NAMESPACE || true     # don't allow the set -e to take effect here
echo ""


echo "${yellow}Installing $PROMETHEUS_APPNAME ... ${white}"

TEMPFILE=$(mktemp) 
cat <<EOF > $TEMPFILE
pushgateway:
  nodeSelector:
    hub.jupyter.org/node-purpose: core
kubeStateMetrics:
  nodeSelector:
    hub.jupyter.org/node-purpose: core
alertmonitor:
  nodeSelector:
    hub.jupyter.org/node-purpose: core
alertmanager:
  persistentVolume:
    storageClass: $STORAGE_CLASS
  nodeSelector:
    hub.jupyter.org/node-purpose: core
server:
  persistentVolume:
    storageClass: $STORAGE_CLASS
  nodeSelector:
    hub.jupyter.org/node-purpose: core

nodeExporter:
  tolerations:
  - effect: NoSchedule
    key: hub.jupyter.org/dedicated
    operator: Equal
    value: user
  - effect: NoSchedule
    key: hub.jupyter.org_dedicated
    operator: Equal
    value: user
EOF

helm upgrade $PROMETHEUS_APPNAME $SCRIPT_DIR/.. --namespace $NAMESPACE --timeout 1m0s --atomic --cleanup-on-fail --install --values $TEMPFILE

rm $TEMPFILE


echo ""
echo "${green}Success! ${white}"
echo ""


