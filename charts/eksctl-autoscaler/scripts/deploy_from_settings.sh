#!/bin/bash

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0  settings.vars" 1>&2
  echo "This script deploys a cluster autoscaler. It is only for use on AWS EKS," 1>&2
  echo "the CLUSTER_NAME should be the same as created in the eksctl manifest, and it will be installed in kube-system namespace."
  echo "Where settings.vars contains at least these vars:" 1>&2
  echo "EKS_CLUSTER_NAME=mycluster" 1>&2
  echo "AUTOSCALER_APPNAME=example-scaler" 1>&2
  echo "KUBE_CONTEXT=devContext" 1>&2
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

validate_set EKS_CLUSTER_NAME "$EKS_CLUSTER_NAME" "^[[:alnum:]_-]+$" required
validate_set AUTOSCALER_APPNAME "$AUTOSCALER_APPNAME" "^[[:alnum:]_-]+$" required
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" required

kubectl config use-context $KUBE_CONTEXT

echo "${yellow}Installing $AUTOSCALER_APPNAME ... ${white}"

TEMPFILE=$(mktemp) 
cat <<EOF > $TEMPFILE
clusterName: ${EKS_CLUSTER_NAME}
nodeSelector:
  nodegroup-role: clustertools
  #hub.jupyter.org/node-purpose: core
EOF

helm upgrade $AUTOSCALER_APPNAME $SCRIPT_DIR/.. --namespace kube-system --timeout 5m0s --atomic --cleanup-on-fail --install --values $TEMPFILE

rm $TEMPFILE


echo ""
echo "${green}Success! ${white}"
echo ""
