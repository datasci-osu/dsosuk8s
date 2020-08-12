# if default namespace, check and see if they've asked for one in the values, 
# if not leave it as default
if [ "$HELM_NAMESPACE" != "kube-system" ]; then
  echo "${yellow}Warning: using kube-system namespace (required).${white}" 1>&2
  HELM_NAMESPACE=kube-system
fi

# if no --kube-context specified, see if they've asked for one
# if not use the current context
if [ "$HELM_KUBECONTEXT" == "" ]; then
  HELM_KUBECONTEXT=$(index kubeContext $(kubectl config current-context))
fi

echo "${yellow}Using kube-context:${white} $HELM_KUBECONTEXT " 1>&2


