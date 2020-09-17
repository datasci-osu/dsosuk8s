# if default namespace, check and see if they've asked for one in the values, 
# if not leave it as default
VALUES_NS=$(index createNamespace "")
if [ "$VALUES_NS" != "" ]; then
  echo "${yellow}WARNING: using namespace ${cyan}$VALUES_NS${yellow} from specified values.${white}" 2>&1
  HELM_NAMESPACE=$VALUES_NS
  CREATING="True"
fi

VALUES_CONTEXT=$(index kubeContext "")
if [ "$VALUES_CONTEXT" != "" ]; then
  echo "${yellow}WARNING: using kube-context ${cyan}$VALUES_CONTEXT${yellow} from specified values.${white}" 2>&1
  HELM_KUBECONTEXT=$VALUES_CONTEXT
fi

if [ "$CREATING" == "True" ]; then
  if [ "$DRY_RUN" == "True" ]; then
    echo "${yellow}Not creating namespace (dry run), but would with: ${white} kubectl create namespace $HELM_NAMESPACE --context $HELM_KUBECONTEXT" 2>&1
  else
    echo "${yellow}Creating namespace with: ${cyan} kubectl create namespace $HELM_NAMESPACE --context $HELM_KUBECONTEXT ${white}" 2>&1
    kubectl create namespace $HELM_NAMESPACE --context $HELM_KUBECONTEXT || true
  fi
fi


echo "Using namespace:${cyan} $HELM_NAMESPACE${white}" 2>&1
echo "Using kube-context:${cyan} $HELM_KUBECONTEXT${white}" 2>&1

