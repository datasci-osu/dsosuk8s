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
  echo "The following may have also been changed on deployment (defaults shown):" 1>&2
  echo "DRIVE_APPNAME=homedrive-\$APPNAME" 1>&2
  echo "NAMESPACE=\$APPNAME" 1>&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi


source $1

validate_set APPNAME "$APPNAME" "^[[:alnum:]_-]+$" ""
validate_set DRIVE_APPNAME "homedrive-$APPNAME" "^[[:alnum:]_-]+$" ""
validate_set NAMESPACE "$NAMESPACE" "^[[:alnum:]_-]+$" "$APPNAME"
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" ""

kubectl config use-context $KUBE_CONTEXT



echo "${red}Warning: This will delete all data for $DRIVE_APPNAME in namespace $NAMESPACE. ${white}"

echo -n "Removing in ";
for i in $(seq 5 1); do
  echo -n "$i... "
  sleep 1
done
echo ""
echo ""

echo "${yellow}Deleting drive containers... ${white}"
echo "${magenta}helm delete $DRIVE_APPNAME --namespace $NAMESPACE ${white}"
helm delete $DRIVE_APPNAME --namespace $NAMESPACE
echo ""

PVCNAME=$(kubectl get pvc --namespace $NAMESPACE | grep $DRIVE_APPNAME | awk '{print $1}')
PVNAME=$(kubectl get pvc --namespace $NAMESPACE | grep $DRIVE_APPNAME | awk '{print $3}')

echo "${yellow}Deleting drive PVC... ${white}"
echo "${magenta}kubectl delete pvc $PVCNAME --namespace $NAMESPACE ${white}"
kubectl delete pvc $PVCNAME --namespace $NAMESPACE
echo ""

echo "${yellow}Deleting drive PV... ${white}"
echo "${magenta}kubectl delete pv $PVNAME ${white}"
kubectl delete pv $PVNAME
echo ""


echo ""
echo "${green}Success! ${white}"
echo ""







