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

source $1

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))
SETTINGS_DIR=$(realpath $(dirname $1))

validate_set HUB_APPNAME "$HUB_APPNAME" "^[[:alnum:]_-]+$" required
validate_set AUTH_TYPE "$AUTH_TYPE" "^(lti|saml|native|dummy)$" required
validate_set ADMIN_USERS "$ADMIN_USERS" "^([[:alnum:]]+\,)*([[:alnum:]]+)$" required
validate_set BASE_URL "$BASE_URL" "^/[[:alnum:]_-]+/$" required
validate_set HUB_IMAGE "$HUB_IMAGE" ".*" required
validate_set USER_IMAGE "$USER_IMAGE" ".*" required
validate_set NUM_PLACEHOLDERS "$NUM_PLACEHOLDERS" "^[[:digit:]]+$" required
validate_set MEM_GUARANTEE "$MEM_GUARANTEE" "^([[:digit:]]*\.)?([[:digit:]]+)G$" required
validate_set MEM_LIMIT "$MEM_LIMIT" "^([[:digit:]]*\.)?([[:digit:]]+)G$" required
validate_set CPU_GUARANTEE "$CPU_GUARANTEE" "^([[:digit:]]*\.)?([[:digit:]]+)$" required
validate_set CPU_LIMIT "$CPU_LIMIT" "^([[:digit:]]*\.)?([[:digit:]]+)$" required
validate_set DRIVE_APPNAME "$DRIVE_APPNAME" ".*" required
validate_set HUB_APPNAME "$HUB_APPNAME" ".*" required
validate_set CLUSTER_HOSTNAME "$CLUSTER_HOSTNAME" "^([[:alnum:]_-]+\.)*([[:alnum:]_-]+)$" required
validate_set NAMESPACE "$NAMESPACE" "^[[:alnum:]_-]+$" required
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" required

if [ $AUTH_TYPE == "lti" ]; then
  validate_set LTI_ID_KEY "$LTI_ID_KEY" "^[[:alnum:]_-]+$" required
  validate_set LTI_ID_REGEX "$LTI_ID_REGEX" ".*" required
  validate_set LTI_ADMIN_ROLES "$LTI_ADMIN_ROLES" "^([[:alnum:]:/_-]+\,)*([[:alnum:]:/_-]+)$" required
fi

kubectl config use-context $KUBE_CONTEXT

# create namespace if it doesn't exist
echo "${yellow}Checking namespace... ${white}"
kubectl create namespace $NAMESPACE || true     # don't allow the set -e to take effect here
echo ""


echo "${yellow}Installing $HUB_APPNAME ... ${white}"
echo ""

# keys needed for canvas repeatable, hashed based on URL, kube context name, and admin users list
LTI_CLIENT_KEY=$(echo ${CLUSTER_HOSTNAME}${BASE_URL}${KUBE_CONTEXT}${ADMIN_USERS} | sha256sum | awk '{print $1}')
LTI_CLIENT_SECRET=$(echo ${ADMIN_USERS}${BASE_URL}${CLUSTER_HOSTNAME}${KUBE_CONTEXT} | sha256sum | awk '{print $1}')

#cat <<EOF | helm template $SCRIPT_DIR/.. --values -
# this bug: https://github.com/helm/helm/issues/7002
# I'd like to use a named pipe here but not sure how to do the cat <<EOF > somenamedpipe and have it not block (even with & it does)
TEMPFILE=$(mktemp) 
cat <<EOF > $TEMPFILE
jupyterhub:
  hub:
    extraEnv:
      AUTH_TYPE: $AUTH_TYPE
      LTI_CLIENT_KEY: $LTI_CLIENT_KEY
      LTI_CLIENT_SECRET: $LTI_CLIENT_SECRET
      ADMIN_USERS: $ADMIN_USERS
      LTI_ID_KEY: "${LTI_ID_KEY:-}"
      LTI_ID_REGEX: "${LTI_ID_REGEX:-}"
      LTI_ADMIN_ROLES: "${LTI_ADMIN_ROLES:-}"
    baseUrl: "$BASE_URL"
    image:
      name: oneilsh/ktesting-k8s-hub
      tag: "$HUB_IMAGE"

  scheduling:
    userPlaceholder:
      enabled: true
      replicas: $NUM_PLACEHOLDERS

  cull:
    enabled: true
    timeout: 3600        # cull inactive servers after this long
    maxAge: 28800        # cull servers this old, even if active (0 disables)

  proxy:
    secretToken: $(openssl rand -hex 32)

  singleuser:
    # looks like these should be set null to delete the key (including those defaulted in the jupyterhub chart) for the c.Spawner limits below to be used
    memory:
      limit: "$MEM_LIMIT"
      guarantee: "$MEM_GUARANTEE"
    cpu:
      limit: $CPU_LIMIT
      guarantee: $CPU_GUARANTEE
    image:
      name: oneilsh/ktesting-datascience-notebook
      tag: "$USER_IMAGE" 
    defaultUrl: "/lab/tree/{username}"

    extraEnv:
      NFS_SVC_HOME: "$DRIVE_APPNAME"   # same as above

    uid: 0
    fsGid: 0

  ingress:
    hosts:
    - $CLUSTER_HOSTNAME
    tls:
    - hosts:
      - $CLUSTER_HOSTNAME

EOF


helm upgrade $HUB_APPNAME $SCRIPT_DIR/.. --namespace $NAMESPACE --timeout 5m0s --atomic --cleanup-on-fail --install --values $TEMPFILE

rm $TEMPFILE


if [ $AUTH_TYPE == "lti" ]; then
  echo "${green}Finished! Your hub is at ${blue}https://${CLUSTER_HOSTNAME}${BASE_URL}hub/lti/launch ${white}"
else
  echo "${green}Finished! Your hub is at ${blue}https://$CLUSTER_HOSTNAME$BASE_URL ${white}"
fi
if [ $AUTH_TYPE == "lti" ]; then
  echo "${green}Your LTI_CLIENT_KEY is ${blue}$LTI_CLIENT_KEY ${white}"
  echo "${green}Your LTI_CLIENT_SECRET is ${blue}$LTI_CLIENT_SECRET ${white}"
fi
echo ""









