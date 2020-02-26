#!/bin/bash

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0  settings.vars" 1>&2
  echo "" 1>&2
  echo "settings.vars should contains at least these vars:"
  echo "AUTOSCALER_APPNAME=example-drive" 1>&2
  echo "KUBE_CONTEXT=devContext"
  echo "" 1>&2
  exit 1
}

if [ "$#" -ne 1 ] && [ "$#" -ne 2 ]; then
  usage
  exit 1
fi


source $1

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))
SETTINGS_DIR=$(realpath $(dirname $1))

validate_set AUTOSCALER_APPNAME "$AUTOSCALER_APPNAME" "^[[:alnum:]_-]+$" required
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" required

kubectl config use-context $KUBE_CONTEXT



echo "${red}Warning: This will delete all data for $AUTOSCALER_APPNAME in namespace $NAMESPACE. ${white}"
echo -n "${yellow}Type the APPNAME ($AUTOSCALER_APPNAME) to continue: ${white}"
read CHECKNAME
if [ ${CHECKNAME} != $AUTOSCALER_APPNAME ]; then
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

echo "${yellow}Deleting autoscaler... ${white}"
echo "${magenta}helm delete $AUTOSCALER_APPNAME --namespace kube-system ${white}"
helm delete $AUTOSCALER_APPNAME --namespace kube-system
echo ""


echo ""
echo "${green}Success! ${white}"
echo ""







