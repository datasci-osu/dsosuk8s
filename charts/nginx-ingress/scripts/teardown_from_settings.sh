#!/bin/bash

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0  settings.vars  [--remove-namespace]" 1>&2
  echo "--remove-namespace is optional; it will only be removed if 'No resources found' is reported for \`kubectl get all --namespace\`" 1>&2
  echo "" 1>&2
  echo "settings.vars should contains at least these vars:"
  echo "NAMESPACE=nginx" 1>&2
  echo "NGINX_APPNAME=nginx-app" 1>&2
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
validate_set NGINX_APPNAME "$NGINX_APPNAME" "^[[:alnum:]_-]+$" required
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" required

kubectl config use-context $KUBE_CONTEXT



echo "${red}Warning: This will delete all data for $NGINX_APPNAME in namespace $NAMESPACE. ${white}"
if [ ! -z $REMOVE_NAMESPACE ]; then
  echo "${red}It will also remove the namespace $NAMESPACE, unless other resources still exist. ${white}"
fi
echo -n "${yellow}Type the APPNAME ($NGINX_APPNAME) to continue: ${white}"
read CHECKNAME
if [ ${CHECKNAME} != $NGINX_APPNAME ]; then
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

echo "${yellow}Deleting prometheus resources... ${white}"
echo "${magenta}helm delete $NGINX_APPNAME --namespace $NAMESPACE ${white}"
helm delete $NGINX_APPNAME --namespace $NAMESPACE
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







