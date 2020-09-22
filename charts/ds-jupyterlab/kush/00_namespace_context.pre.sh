
# use values-supplied context if there is one
VALUES_CONTEXT=$(index kubeContext "")
if [ "$VALUES_CONTEXT" != "" ]; then
  echo "${yellow}WARNING: using kube-context ${cyan}$VALUES_CONTEXT${yellow} from specified values.${white}" 2>&1
  HELM_KUBECONTEXT=$VALUES_CONTEXT
fi

# force namespace to be the same as the release name
HELM_NAMESPACE=$RELEASE_NAME

if [ "$DRY_RUN" == "True" ]; then
  echo "${yellow}Not creating namespace (dry run), but would with: ${white} kubectl create namespace $HELM_NAMESPACE --context $HELM_KUBECONTEXT" 2>&1
else
  echo "${yellow}Creating namespace with: ${cyan} kubectl create namespace $HELM_NAMESPACE --context $HELM_KUBECONTEXT ${white}" 2>&1
  kubectl create namespace $HELM_NAMESPACE --context $HELM_KUBECONTEXT || true
fi

echo "${yellow}Using namespace:${white} $HELM_NAMESPACE " 2>&1
echo "${yellow}Using kube-context:${white} $HELM_KUBECONTEXT " 2>&1

