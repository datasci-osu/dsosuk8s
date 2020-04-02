#!/bin/bash -e

set -e

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))
SETTINGS_DIR=$(realpath $(dirname $1))
source $SCRIPT_DIR/utils.src

usage () {
  echo "${red}Usage: $0  settings.vars ${white}" 1>&2
  echo "${red}This script assumes a corresponding nfs-drive app has already been created, and should be called from hub_deploy.sh.${white}"
  echo "${red}Where settings.vars contains at least these vars (examples shown): ${white}" 1>&2
  echo "APPNAME=example-deployment" 1>&2
  echo "CLUSTER_HOSTNAME=dev.host.edu" 1>&2
  echo "KUBE_CONTEXT=devB" 1>&2
  echo "SECURITY_SALT=anything-alphanumeric-and-_s" 1>&2 
  echo "" 1>&2
  echo "${yellow}The following are optional but recommended to be set (defaults shown): ${white}" 1>&2
  echo "NUM_PLACEHOLDERS=3" 1>&2
  echo "MEM_GUARANTEE=0.5G" 1>&2
  echo "MEM_LIMIT=1G" 1>&2
  echo "CPU_GUARANTEE=0.1" 1>&2
  echo "CPU_LIMIT=1" 1>&2
  echo "" 1>&2
  echo "${yellow}The following can also be optionally set (defaults shown): ${white}" 1>&2 
  echo "AUTH_TYPE=lti              # (lti|native|dummy)" 1>&2
  echo "ADMIN_USERS=oneils,smithj  # ignored if AUTH_TYPE is lti" 1>&2
  echo "BASE_URL=/\$APPNAME/" 1>&2
  echo "HUB_APPNAME=hub-\$APPNAME" 1>&2
  echo "DRIVE_APPNAME=homedrive-\$APPNAME" 1>&2
  echo "NAMESPACE=\$APPNAME" 1>&2
  echo "" 1>&2
  echo "${yellow}If AUTH_TYPE=lti, the following or similar can also be set (defaults shown for OSU Canvas, note JSON encoding): ${white}" 1>&2
  echo "${blue}# the keys returned by the LTI API holding usernames to search against ${white}" 1>&2
  echo "LTI_ID_KEYS='[\"custom_canvas_user_login_id\", \"lis_person_contact_email_primary\", \"custom_canvas_user_login_id\"]'" 1>&2
  echo "${blue}# regexes to extract username from first matching key with ${white}" 1>&2
  echo "LTI_ID_REGEXES='[\"(^[^@]+)@oregonstate.edu$\", \"(^[^@]+@[^@]+$)\", \"(^[0-9a-f]{6,6})[0-9a-f]*$\"]'" 1>&2
  echo "${blue}# LTI 'roles' to grant jupterhub admin access to. ${white}" 1>&2
  echo "LTI_ADMIN_ROLES='[\"Instructor\", \"TeachingAssistant\", \"ContentDeveloper\"]'" 1>&2
  echo "" 1>&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

source $1


validate_set APPNAME "$APPNAME" "^[[:alnum:]_-]+$" ""
validate_set CLUSTER_HOSTNAME "$CLUSTER_HOSTNAME" "^([[:alnum:]_-]+\.)*([[:alnum:]_-]+)$" ""
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" ""
validate_set SECURITY_SALT "$SECURITY_SALT" "^[[:alnum:]_-]+$" ""

validate_set ADMIN_USERS "$ADMIN_USERS" "^(([[:alnum:]]+\,)*([[:alnum:]]+))?$" ""
validate_set AUTH_TYPE "$AUTH_TYPE" "^(lti|saml|native|dummy)$" lti
validate_set BASE_URL "$BASE_URL" "^/[[:alnum:]_-]+/$" "/$APPNAME/"
validate_set NUM_PLACEHOLDERS "$NUM_PLACEHOLDERS" "^[[:digit:]]+$" 3
validate_set MEM_GUARANTEE "$MEM_GUARANTEE" "^([[:digit:]]*\.)?([[:digit:]]+)G$" 0.5G
validate_set MEM_LIMIT "$MEM_LIMIT" "^([[:digit:]]*\.)?([[:digit:]]+)G$" 1.0G
validate_set CPU_GUARANTEE "$CPU_GUARANTEE" "^([[:digit:]]*\.)?([[:digit:]]+)$" 0.1
validate_set CPU_LIMIT "$CPU_LIMIT" "^([[:digit:]]*\.)?([[:digit:]]+)$" 1.0
validate_set DRIVE_APPNAME "$DRIVE_APPNAME" "^[[:alnum:]_-]+$" "homedrive-$APPNAME"
validate_set HUB_APPNAME "$HUB_APPNAME" "^[[:alnum:]_-]+$" "hub-$APPNAME"
validate_set NAMESPACE "$NAMESPACE" "^[[:alnum:]_-]+$" "$APPNAME"
# JSON doesn't support single quotes (at least not python's json.loads), so we have to use double-quotes internally
validate_set LTI_ID_KEYS "$LTI_ID_KEYS" ".+" "[\\\"custom_canvas_user_login_id\\\", \\\"lis_person_contact_email_primary\\\", \\\"custom_canvas_user_login_id\\\"]"
validate_set LTI_ID_REGEXES "$LTI_ID_REGEXES" ".+" "[\\\"(^[^@]+)@oregonstate.edu$\\\", \\\"(^[^@]+@[^@]+$)\\\", \\\"(^[0-9a-f]{6,6})[0-9a-f]*$\\\"]"
validate_set LTI_ADMIN_ROLES "$LTI_ADMIN_ROLES" ".+" "[\\\"Instructor\\\", \\\"TeachingAssistant\\\", \\\"ContentDeveloper\\\"]"

### TODO SHAWN: continue refactor from here...

kubectl config use-context $KUBE_CONTEXT

# create namespace if it doesn't exist
echo "${yellow}Checking namespace... ${white}"
kubectl create namespace $NAMESPACE || true     # don't allow the set -e to take effect here
echo ""


echo "${yellow}Installing $HUB_APPNAME ... ${white}"
echo ""

# keys needed for canvas repeatable, hashed based on URL, kube context name, and admin users list
LTI_CLIENT_KEY=$(echo ${CLUSTER_HOSTNAME}${BASE_URL}${KUBE_CONTEXT}${ADMIN_USERS}${SECURITY_SALT} | sha256sum | awk '{print $1}')
LTI_CLIENT_SECRET=$(echo ${SECURITY_SALT}${ADMIN_USERS}${BASE_URL}${CLUSTER_HOSTNAME}${KUBE_CONTEXT} | sha256sum | awk '{print $1}')

#cat <<EOF | helm template $SCRIPT_DIR/.. --values -
# this bug: https://github.com/helm/helm/issues/7002
# I'd like to use a named pipe here but not sure how to do the cat <<EOF > somenamedpipe and have it not block (even with & it does)
TEMPFILE=$(mktemp) 
cat <<EOF > $TEMPFILE
jupyterhub:
  hub:
    extraEnv:
      AUTH_TYPE: "$AUTH_TYPE"
      LTI_CLIENT_KEY: "$LTI_CLIENT_KEY"
      LTI_CLIENT_SECRET: "$LTI_CLIENT_SECRET"
      ADMIN_USERS: "$ADMIN_USERS"
      # and we use single quotes here cuz the json has double quotes inside...
      LTI_ID_KEYS: '${LTI_ID_KEYS:-}'
      LTI_ID_REGEXES: '${LTI_ID_REGEXES:-}'
      LTI_ADMIN_ROLES: '${LTI_ADMIN_ROLES:-}'
      NFS_SVC_HOME: "$DRIVE_APPNAME"   # same as above
    baseUrl: "$BASE_URL"

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

    extraEnv:
      NFS_SVC_HOME: "$DRIVE_APPNAME"   # same as above

  ingress:
    hosts:
    - "$CLUSTER_HOSTNAME"
    tls:
    - hosts:
      - "$CLUSTER_HOSTNAME"

EOF

helm upgrade $HUB_APPNAME $SCRIPT_DIR/.. --namespace $NAMESPACE --timeout 4m0s --atomic --cleanup-on-fail --install --values $TEMPFILE --post-renderer $SCRIPT_DIR/../kustomizations/kustomizer.sh

rm $TEMPFILE


if [ $AUTH_TYPE == "lti" ]; then
  echo "${green}Finished! Your hub is at ${blue}https://${CLUSTER_HOSTNAME}${BASE_URL}hub/lti/launch ${white}"
else
  echo "${green}Finished! Your hub is at ${blue}https://$CLUSTER_HOSTNAME$BASE_URL ${white}"
fi
if [ $AUTH_TYPE == "lti" ]; then
  echo "${green}Your Consumer Key is ${blue}$LTI_CLIENT_KEY ${white}"
  echo "${green}Your Shared Secret is ${blue}$LTI_CLIENT_SECRET ${white}"
fi
echo ""









