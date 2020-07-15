if ! $(which yq > /dev/null); then
  echo "${red}This chart requires the yq utility (and its dependency jq). https://github.com/mikefarah/yq ${white}" 1>&2
  exit 1
fi

function error {
  echo "${red}$1${white}" 1>&2 
  exit 1
}

if [ -z "$USER_VALUES_FILES" ]; then
  error "You need to supply --values for this chart."
fi

# use --kube-context if provided
KUBE_CONTEXT=$HELM_KUBECONTEXT
# if not, grab it from --values, error if not found in either
if [ -z "$KUBE_CONTEXT" ]; then
  KUBE_CONTEXT=$(cat $USER_VALUES_FILES | yq .deployment.kubeContext | tr -d '"')
  if [ -z "$KUBE_CONTEXT" ] || [ "$KUBE_CONTEXT" == "null" ]; then
    error "You must specify either jupyterhub: {deployment: {kubeContext: }} in a file given with --values, or use --kube-context in the call to helm."
  fi
fi

# if no release name specified (default is RELEASE-NAME)
if [ "$RELEASE_NAME" == "RELEASE-NAME" ]; then 
  # try and grab it from --values
  RELEASE_NAME=$(cat $USER_VALUES_FILES | yq .deployment.releaseName | tr -d '"')
  # if not given, complain
  if [ -z "$RELEASE_NAME" ] || [ "$RELEASE_NAME" == "null" ]; then
    error "You must specify a release name, either in the call to helm, or in file given with --values in deployment: {releaseName: }. "
  fi
fi

# required from user
CLUSTER_HOSTNAME=$(cat $USER_VALUES_FILES | yq .deployment.clusterHostname | tr -d '"')
if [ -z "$CLUSTER_HOSTNAME" ] || [ "$CLUSTER_HOSTNAME" == "null" ]; then
    error "You must specify the clusters load-balancer/ingress hostname via --values in deployment: {clusterHostname: }. "
fi


# required from user
SECURITY_SALT=$(cat $USER_VALUES_FILES | yq .deployment.securitySalt | tr -d '"')
if [ -z "$SECURITY_SALT" ] || [ "$SECURITY_SALT" == "null" ]; then
    error "You must specify a security salt secret via --values in deployment: {securitySalt: }. "
fi

# if they ask to create the namespace...
CREATE_NAMESPACE=$(cat $USER_VALUES_FILES | yq .deployment.createNamespace | tr -d '"')
if [ "$CREATE_NAMESPACE" == "true" ]; then
  # first check and see if they passed --namespace to helm and create that
  if [ "$HELM_NAMESPACE" == "default" ]; then
    HELM_NAMESPACE=$RELEASE_NAME
  fi
  
  if [ "$DRY_RUN" == "false" ]; then
    echo "${yellow}Creating namespace: ${white}" 1>&2
    kubectl create namespace $HELM_NAMESPACE --context $KUBE_CONTEXT
  else
    echo "${yellow}Not creating namespace (dry-run): ${white}" 1>&2
  fi
  echo "  ${yellow}kubectl create namespace $HELM_NAMESPACE --context $KUBE_CONTEXT${white}" 1>&2
fi

HOMEDRIVE_SIZE=$(cat $USER_VALUES_FILES | yq .deployment.createHomeDrive.size | tr -d '"')
if [ "$HOMEDRIVE_SIZE" == "null" ]; then
  HOMEDRIVE_SVC=$(cat $USER_VALUES_FILES | yq .deployment.homeDriveSvc | tr -d '"')
  if [ "$HOMEDRIVE_SVC" == "null" ]; then
    error "You must specify either a homedrive size to create with e.g. deployment: {createHomeDrive: 20Gi} or an existing service specified with e.g. deployment: {homeDriveSvc: some-release}".
  else
    DRIVE_RELEASE_NAME=$HOMEDRIVE_SVC
  fi
elif echo $HOMEDRIVE_SIZE | grep -Eqs '^[[:digit:]]+(\.[[:digit:]]+){0,1}Gi$'; then
  HOMEDRIVE_CHART=$(cat $USER_VALUES_FILES | yq .deployment.createHomeDrive.chart | tr -d '"')
  if [ "$HOMEDRIVE_CHART" == "null" ]; then
    error "If specifying createHomeDrive in --values, must also specify createHomeDrive: {chart: }."
  fi
  DRIVE_RELEASE_NAME=homedrive-$RELEASE_NAME
  if [ "$DRY_RUN" == "false" ]; then
    echo "${yellow}Installing homedrive: ${white}" 1>&2
    helm upgrade $DRIVE_RELEASE_NAME $HOMEDRIVE_CHART --namespace $HELM_NAMESPACE --timeout 2m0s --atomic --cleanup-on-fail --install --set size=$HOMEDRIVE_SIZE --kube-context $KUBE_CONTEXT
  else
    echo "${yellow}Not installing homedrive (dry-run): ${white}" 1>&2
  fi
  echo "   ${yellow}helm upgrade $DRIVE_RELEASE_NAME $HOMEDRIVE_CHART --namespace $HELM_NAMESPACE --timeout 2m0s --atomic --cleanup-on-fail --install --set size=$HOMEDRIVE_SIZE --kube-context $KUBE_CONTEXT ${white}" 1>&2
else
  error "Value specified in deployment: {createHomeDrive: 20Gi} must match ^[[:digit:]]+(\.[[:digit:]]+){0,1}Gi$, got $HOMEDRIVE_SIZE."	
fi

export RELEASE_NAME
export BASE_URL="/$RELEASE_NAME/"
export CLUSTER_HOSTNAME
export DRIVE_RELEASE_NAME
export AUTH_TYPE=${AUTH_TYPE:-lti}

export LTI_CLIENT_KEY=$(echo ${CLUSTER_HOSTNAME}${BASE_URL}${KUBE_CONTEXT}${ADMIN_USERS:-nobody}${SECURITY_SALT} | sha256sum | awk '{print $1}')
export LTI_CLIENT_SECRET=$(echo ${SECURITY_SALT}${ADMIN_USERS:-nobody}${BASE_URL}${CLUSTER_HOSTNAME}${KUBE_CONTEXT} | sha256sum | awk '{print $1}')

