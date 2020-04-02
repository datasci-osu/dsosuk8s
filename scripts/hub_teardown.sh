#!/bin/bash 

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0 settings.vars" 1>&2
  echo "The namespace will be deleted if 'kubectl get all --namespace' returns nothing." 1>&2
  echo "" 1>&2
  echo "settings.vars should contains at least these vars:"
  echo "APPNAME=example-deployment" 1>&2
  echo "KUBE_CONTEXT=devContext" 1>&2
  echo "" 1>&2
  echo "The following defauls may have been changed during deployment:" 1>&2
  echo "NAMESPACE=\$APPNAME" 1>&2
  echo "DRIVE_APPNAME=homedrive-\$APPNAME" 1>&2
  echo "HUB_APPNAME=hub-\$APPNAME" 1>&2
  echo "" 1>&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

VARS_PATH=$(realpath $1)
source $VARS_PATH

validate_set DRIVE_CHART "$DRIVE_CHART" "((^https://datasci-osu\.github\.io)|(http://127.0.0.1)).+nfs-drive-.+\.tgz" ""
validate_set HUB_CHART "$HUB_CHART" "((^https://datasci-osu\.github\.io)|(http://127.0.0.1)).+ds-jupyterlab-.+\.tgz" ""

validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" ""
validate_set APPNAME "$APPNAME" "^[[:alnum:]_-]+$" ""
validate_set NAMESPACE "$NAMESPACE" "^[[:alnum:]_-]+$" "$APPNAME"

tempdir=$(mktemp -d)
echo "${green}Pulling charts to temp dir $tempdir...${white}"
cd $tempdir


for CHART in $HUB_CHART $DRIVE_CHART ; do
  echo "${green}pulling $CHART...${white}"
  CHARTDIR=$(helm show chart $CHART | grep '^name: ' | sed -r 's/^name: //')
  helm pull --untar $CHART

  echo "${green}Running $CHART scripts/teardown_from_settings.sh...${white}"
  chmod u+x $CHARTDIR/scripts/*.sh || true                # don't fail if they don't exist
  $CHARTDIR/scripts/teardown_from_settings.sh $VARS_PATH
done

echo "${yellow}Attempting to remove namespace $NAMESPACE... ${white}"
safe-delete-namespace $KUBE_CONTEXT $APPNAME

