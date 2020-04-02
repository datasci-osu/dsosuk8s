#!/bin/bash -e


SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))
GIT_ROOT=$(git -C $SCRIPT_DIR rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

VARS_PATH=$(realpath $1)

usage () {
  echo "${red}Usage: $0  settings.vars ${white}" 1>&2
  echo "${red}This script assumes a corresponding nfs-drive app has already been created, and should be called from hub_deploy.sh.${white}"
  echo "${red}Where settings.vars contains at least these vars (examples shown): ${white}" 1>&2
  echo "APPNAME=example-deployment" 1>&2
  echo "CLUSTER_HOSTNAME=dev.host.edu" 1>&2
  echo "KUBE_CONTEXT=devB" 1>&2
  echo "SECURITY_SALT=anything-alphanumeric-and-_s" 1>&2 
  echo "DRIVE_CHART=https://datasci-osu.github.io/dsosuk8s/nfs-drive-1.1.0.tgz" 1>&2
  echo "HUB_CHART=https://datasci-osu.github.io/dsosuk8s/ds-jupyterlab-1.2.0.tgz" 1>&2
  echo "" 1>&2
  echo "${yellow}The following are optional but recommended to be set (defaults shown): ${white}" 1>&2
  echo "NUM_PLACEHOLDERS=3" 1>&2
  echo "MEM_GUARANTEE=0.5G" 1>&2
  echo "MEM_LIMIT=1G" 1>&2
  echo "CPU_GUARANTEE=0.1" 1>&2
  echo "CPU_LIMIT=1" 1>&2
  echo "HOMEDRIVE_SIZE=40Gi" 1>&2
  echo "" 1>&2
  echo "A number of other options can be set (but use good defaults for a Canvas deployment at OSU), see the deploy_from_settings.sh scripts in the charts." 1>&2
  exit 1
}

source $VARS_PATH

validate_set DRIVE_CHART "$DRIVE_CHART" "((^https://datasci-osu\.github\.io)|(http://127.0.0.1)).+nfs-drive-.+\.tgz" ""
validate_set HUB_CHART "$HUB_CHART" "((^https://datasci-osu\.github\.io)|(http://127.0.0.1)).+ds-jupyterlab-.+\.tgz" ""

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

tempdir=$(mktemp -d)
echo "${green}Pulling charts to temp dir $tempdir...${white}"
cd $tempdir


for CHART in $DRIVE_CHART $HUB_CHART ; do
  echo "${green}pulling $CHART...${white}"
  CHARTDIR=$(helm show chart $CHART | grep '^name: ' | sed -r 's/^name: //')
  helm pull --untar $CHART

  echo "${green}Running $CHART scripts/deploy_from_settings.sh...${white}"
  chmod u+x $CHARTDIR/scripts/*.sh || true                # don't fail if they don't exist
  chmod u+x $CHARTDIR/kustomizations/*.sh || true
  $CHARTDIR/scripts/deploy_from_settings.sh $VARS_PATH
done



