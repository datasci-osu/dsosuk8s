#!/bin/bash

set -e 

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))
SETTINGS_DIR=$(realpath $(dirname $1))
source $SCRIPT_DIR/utils.src

usage () {
  echo "Usage: $0  settings.vars" 1>&2
  echo "Where settings.vars contains at least these vars:" 1>&2
  echo "APPNAME=example-deployment" 1>&2
  echo "KUBE_CONTEXT=devContext" 1>&2
  echo "" 1>&2
  echo "The following can also be set (defaults shown):" 1>&2
  echo "HOMEDRIVE_SIZE=40Gi" 1>&2
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
validate_set HOMEDRIVE_SIZE "$HOMEDRIVE_SIZE" "^([[:digit:]]*\.)?([[:digit:]]+)Gi$" 40Gi
validate_set NAMESPACE "$NAMESPACE" "^[[:alnum:]_-]+$" "$APPNAME"
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" ""

kubectl config use-context $KUBE_CONTEXT

# create namespace if it doesn't exist
echo "${yellow}Checking namespace... ${white}"
kubectl create namespace $NAMESPACE || true     # don't allow the set -e to take effect here
echo ""


echo "${yellow}Installing $DRIVE_APPNAME ... ${white}"

TEMPFILE=$(mktemp) 
cat <<EOF > $TEMPFILE
size: ${HOMEDRIVE_SIZE}
EOF

helm upgrade $DRIVE_APPNAME $SCRIPT_DIR/.. --namespace $NAMESPACE --timeout 4m0s --atomic --cleanup-on-fail --install --values $TEMPFILE

rm $TEMPFILE


echo ""
echo "${green}Success! ${white}"
echo ""
