#!/bin/bash 

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0  settings.vars  [--remove-namespace]" 1>&2
  echo "--remove-namespace is optional; it will only be removed if 'No resources found' is reported for \`kubectl get all --namespace\`" 1>&2
  echo "" 1>&2
  echo "settings.vars should contains at least these vars:"
  echo "NAMESPACE=example-namespace" 1>&2
  echo "HUB_APPNAME=example-hub" 1>&2
  echo "KUBE_CONTEXT=devContext"
  echo "" 1>&2
  exit 1
}

if [ "$#" -ne 1 ] && [ "$#" -ne 2 ]; then
  usage
  exit 1
fi

if [ "$#" -eq 2 ]; then
  REMOVE_NAMESPACE=true
fi

source $1

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))
SETTINGS_DIR=$(realpath $(dirname $1))

validate_set NAMESPACE "$NAMESPACE" "^[[:alnum:]_-]+$" required
validate_set HUB_APPNAME "$HUB_APPNAME" "^[[:alnum:]_-]+$" required
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" required

kubectl config use-context $KUBE_CONTEXT


if kubectl get pods --selector=component=singleuser-server --namespace $NAMESPACE 2> /dev/null | grep -q jupyter; then
  echo "${red}Warning: This will kill the following user containers and delete all data for $HUB_APPNAME: ${white}"
  kubectl get pods --selector=component=singleuser-server --namespace $NAMESPACE
else
  echo "${red}Warning: This will delete all data for $HUB_APPNAME. ${white}"
fi

echo -n "${yellow}Type the APPNAME ($HUB_APPNAME) to continue: ${white}"
read CHECKNAME
if [ ${CHECKNAME} != $HUB_APPNAME ]; then
  echo "No match, exiting."
  exit 1
fi

echo -n "Ok, removing in ";
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





if [ ! -z $REMOVE_NAMESPACE ]; then
  echo "${yellow}Trying to delete namespace, checking if empty... ${white}"
  result=$(kubectl get all --namespace $NAMESPACE)
  if [ ! -z "$result" ]; then
    echo "${yellow}Warning: Not removing namespace $NAMESPACE, resources still exist:\n\n$result" 1>&2
    exit 1
  fi

  kubectl delete namespace $NAMESPACE
fi

echo ""
echo "${green}Success! ${white}"
echo ""

