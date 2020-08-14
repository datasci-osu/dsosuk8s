# if no --kube-context specified, see if they've asked for one
# if not use the current context
if [ "$HELM_KUBECONTEXT" == "" ]; then
  HELM_KUBECONTEXT=$(index kubeContext $(kubectl config current-context))
fi


HELM_NAMESPACE=$RELEASE_NAME

if [ "$DRY_RUN" == "True" ]; then
  echo "${yellow}Not creating namespace (dry run), but would with: ${white} kubectl create namespace $HELM_NAMESPACE --context $HELM_KUBECONTEXT" 2>&1
else
  echo "${yellow}Creating namespace with: ${cyan} kubectl create namespace $HELM_NAMESPACE --context $HELM_KUBECONTEXT ${white}" 2>&1
  kubectl create namespace $HELM_NAMESPACE --context $HELM_KUBECONTEXT || true
fi

echo "${yellow}Using namespace:${white} $HELM_NAMESPACE " 2>&1
echo "${yellow}Using kube-context:${white} $HELM_KUBECONTEXT " 2>&1

