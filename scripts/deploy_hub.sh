#!/bin/bash -e

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0  settings.vars" 1>&2
  echo "Where settings.vars contains at least these vars (examples shown):" 1>&2
  echo "HUB_APPNAME=example-hub" 1>&2
  echo "AUTH_TYPE=lti" 1>&2
  echo "ADMIN_USERS=oneils,smithj" 1>&2
  echo "BASE_URL=/example-hub/" 1>&2
  echo "HUB_IMAGE=v1.2.1"
  echo "USER_IMAGE=v1.1.4" 1>&2
  echo "NUM_PLACEHOLDERS=2" 1>&2
  echo "MEM_GUARANTEE=0.5G" 1>&2
  echo "MEM_LIMIT=1G" 1>&2
  echo "CPU_GUARANTEE=0.1" 1>&2
  echo "CPU_LIMIT=2" 1>&2
  echo "HOMEDRIVE_SIZE=4Gi" 1>&2
  echo "DRIVE_APPNAME=example-drive" 1>&2
  echo "CLUSTER_HOSTNAME=dev.host.edu" 1>&2
  echo "NAMESPACE=example" 1>&2
  echo "KUBE_CONTEXT=devB" 1>&2
  echo "" 1>&2
  echo "If AUTH_TYPE=lti, the following or similar should also be set:" 1>&2
  echo "LTI_ID_KEY=custom_canvas_user_login_id  # the key returned by the LTI API holding usernames" 1>&2
  echo "LTI_ID_REGEX='(^[^@]+).*'               # regex to extract username from key with (this extracts before the @ in an email)" 1>&2
  echo "LTI_ADMIN_ROLES='Administrator,:role:ims/lis/Instructor'   # LTI 'roles' to grant jupterhub admin access to, matched to suffixed returned by LTI API." 1>&2
  echo "" 1>&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

$GIT_ROOT/charts/drive/scripts/deploy_from_settings.sh "$@"
$GIT_ROOT/charts/ds-jupyterlab/scripts/deploy_from_settings.sh "$@"

