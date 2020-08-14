SECURITY_SALT=$(index securitySalt "")

HOMEDRIVE_SIZE=$(index createHomeDrive.size "")

if [ "$HOMEDRIVE_SIZE" != "" ]; then
  DRIVE_RELEASE_NAME="${RELEASE_NAME}homedrive"
  HOMEDRIVE_CHART=$(index createHomeDrive.chart "")
  if [ "$HOMEDRIVE_CHART" == "" ]; then
    echo "${red}You must have a createHomeDrive.chart specified in --values. ${white}" 1>&2
    exit 1
  fi  
  if [ "$DRY_RUN" == "False" ]; then
    echo "${yellow}Warning, installing home drive with: ${white}" 1>&2
    echo "helm kush upgrade $DRIVE_RELEASE_NAME $HOMEDRIVE_CHART --namespace $HELM_NAMESPACE --timeout 2m0s --atomic --cleanup-on-fail --install --set size=$HOMEDRIVE_SIZE --kube-context $HELM_KUBECONTEXT --kush-interpolate"
    helm kush upgrade $DRIVE_RELEASE_NAME $HOMEDRIVE_CHART --namespace $HELM_NAMESPACE --timeout 2m0s --atomic --cleanup-on-fail --install --set size=$HOMEDRIVE_SIZE --kube-context $HELM_KUBECONTEXT --kush-interpolate
  else
    echo "${yellow}Warning, NOT installing homedrive (--dry-run or template used), but would otherwise with: ${white}" 1>&2
    echo "helm kush upgrade $DRIVE_RELEASE_NAME $HOMEDRIVE_CHART --namespace $HELM_NAMESPACE --timeout 2m0s --atomic --cleanup-on-fail --install --set size=$HOMEDRIVE_SIZE --kube-context $HELM_KUBECONTEXT --kush-interpolate"
  fi
fi

# variables used by values.yaml
# DRIVE_RELEASE_NAME (set above)
LTI_CLIENT_KEY=$(echo ${HELM_NAMESPACE}${RELEASE_NAME}${HELM_KUBECONTEXT}${ADMIN_USERS:-nobody} | sha256sum | awk '{print $1}')
LTI_CLIENT_SECRET=$(echo ${SECURITY_SALT}${ADMIN_USERS:-nobody}${HELM_KUBECONTEXT}${HELM_NAMESPACE}${HELM_KUBECONTEXT} | sha256sum | awk '{print $1}')

