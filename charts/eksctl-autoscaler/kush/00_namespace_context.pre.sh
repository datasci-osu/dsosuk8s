# use values-supplied context if there is one
VALUES_CONTEXT=$(index kubeContext "")
if [ "$VALUES_CONTEXT" != "" ]; then
  echo "${yellow}WARNING: using kube-context ${cyan}$VALUES_CONTEXT${yellow} from specified values.${white}" 2>&1
  HELM_KUBECONTEXT=$VALUES_CONTEXT
fi

# force namespace to be kube-system (req for autoscaler)
HELM_NAMESPACE=kube-system

echo "${yellow}Using namespace:${white} $HELM_NAMESPACE " 2>&1
echo "${yellow}Using kube-context:${white} $HELM_KUBECONTEXT " 2>&1

