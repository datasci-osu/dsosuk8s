#!/bin/bash 

set -e

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))
SETTINGS_DIR=$(realpath $(dirname $1))
source $SCRIPT_DIR/utils.src

usage () {
  echo "Usage: $0 settings.vars" 1>&2
  echo "settings.vars should contains at least these vars:"
  echo "APPNAME=example-deployment" 1>&2
  echo "KUBE_CONTEXT=devContext"
  echo "" 1>&2
  echo "These are set to defaults but could have been changed for install:" 1>&2
  echo "HUB_APPNAME=hub-\$APPNAME" 1>&2
  echo "NAMESPACE=\$APPNAME" 1>&2
  echo "" 1>&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi


source $1

validate_set APPNAME "$APPNAME" "^[[:alnum:]_-]+$" ""
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" ""
validate_set NAMESPACE "$NAMESPACE" "^[[:alnum:]_-]+$" "$APPNAME"
validate_set HUB_APPNAME "hub-$APPNAME" "^[[:alnum:]_-]+$" ""


kubectl config use-context $KUBE_CONTEXT


if kubectl get pods --selector=component=singleuser-server --namespace $NAMESPACE 2> /dev/null | grep -q jupyter; then
  echo "${red}Warning: This will kill the following user containers and delete all data for $HUB_APPNAME: ${white}"
  kubectl get pods --selector=component=singleuser-server --namespace $NAMESPACE
else
  echo "${red}Warning: This will delete all data for $HUB_APPNAME. ${white}"
fi


echo -n "Removing in ";
for i in $(seq 5 1); do
  echo -n "$i... "
  sleep 1
done
echo ""
echo ""

if kubectl get pods --selector=component=singleuser-server --namespace $NAMESPACE 2> /dev/null | grep -q jupyter; then
  echo "${yellow}Deleting user containers... $white"
  echo "${magenta}kubectl delete pods --selector=component=singleuser-server --namespace $NAMESPACE ${white}"
  kubectl delete pods --selector=component=singleuser-server --namespace $NAMESPACE
  echo ""
fi

echo "${yellow}Deleting hub resources... ${white}"
echo "${magenta}helm delete $HUB_APPNAME --namespace $NAMESPACE ${white}"
helm delete $HUB_APPNAME --namespace $NAMESPACE
echo ""






echo ""
echo "${green}Success! ${white}"
echo ""

