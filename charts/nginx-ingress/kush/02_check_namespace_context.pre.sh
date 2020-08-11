# if default namespace, check and see if they've asked for one in the values, 
# if not leave it as default
if [ "$HELM_NAMESPACE" == "default" ]; then
  HELM_NAMESPACE=$(index createNamespace "default")

  # if the namespace is still not default, they had .createNamespace set and thus want it actually created
  if [ "$HELM_NAMESPACE" != "default" ]; then
    CREATING="True"
  fi
fi

# if no --kube-context specified, see if they've asked for one
# if not use the current context
if [ "$HELM_KUBECONTEXT" == "" ]; then
  HELM_KUBECONTEXT=$(index kubeContext $(kubectl config current-context))
fi

echo "${yellow}Using namespace:${white} $HELM_NAMESPACE " 2>&1
echo "${yellow}Using kube-context:${white} $HELM_KUBECONTEXT " 2>&1

# create the namespace, but only if it's not a dry-run situation, we're not targetting the default namespace,
# and we got the namespace via .createNamespace
if [ "$HELM_NAMESPACE" != "default" ] && [ "$CREATING" == "True" ]; then
  # if create the namespace, if we're not in a dry-run situation
  if [ "$DRY_RUN" == "True" ]; then
    echo "${yellow}Not creating namespace (dry run), but would with: ${white} kubectl create namespace $HELM_NAMESPACE " 2>&1
  else
    echo "${yellow}Creating namespace with: ${cyan} kubectl create namespace $HELM_NAMESPACE ${white}" 2>&1
    kubectl create namespace $HELM_NAMESPACE || true
  fi
fi

