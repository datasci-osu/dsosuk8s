#!/bin/bash -e

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0  settings.vars" 1>&2
  echo "Where settings.vars contains at least these vars:"
  echo "WILDCARD_CERT=certs/wildcardTLS.cert   # relative to settings.vars file" 1>&2
  echo "WILDCARD_KEY=certs/wildcardTLS.key     # relative to settings.vars file" 1>&2
  echo "MAX_UPLOAD_SIZE=200M" 1>&2
  echo "CLUSTER_HOSTNAME=yourcluster.host.edu  # corresponds to certs"
  echo "NAMESPACE=example-namespace" 1>&2
  echo "NGINX_APPNAME=example-drive" 1>&2
  echo "KUBE_CONTEXT=devContext"
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

validate_set WILDCARD_CERT "$WILDCARD_CERT" "^.*$" required
validate_set WILDCARD_KEY "$WILDCARD_KEY" "^.*$" required
validate_set MAX_UPLOAD_SIZE "$MAX_UPLOAD_SIZE" "^[[:digit:]]+(m|M|G)$" required
validate_set CLUSTER_HOSTNAME "$CLUSTER_HOSTNAME" "^([[:alnum:]_-]+\.)*([[:alnum:]_-]+)$" required
validate_set NAMESPACE "$NAMESPACE" "^[[:alnum:]_-]+$" required
validate_set NGINX_APPNAME "$NGINX_APPNAME" "^[[:alnum:]_-]+$" required
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" required

kubectl config use-context $KUBE_CONTEXT

# create namespace if it doesn't exist
echo "${yellow}Checking namespace... ${white}"
kubectl create namespace $NAMESPACE || true     # don't allow the set -e to take effect here
echo ""


echo "${yellow}Installing $NGINX_APPNAME ... ${white}"

WILDCARD_CERT_64=$(base64 $WILDCARD_CERT)
WILDCARD_KEY_64=$(base64 $WILDCARD_KEY)


TEMPFILE=$(mktemp) 
cat <<EOF > $TEMPFILE
nginx-ingress:
  controller:
    wildcardTLS:
      cert: $WILDCARD_CERT_64
      key: $WILDCARD_KEY_64
    config:
      entries:
        client-max-body-size: $MAX_UPLOAD_SIZE
masterHost: $CLUSTER_HOSTNAME

EOF

helm upgrade $NGINX_APPNAME $SCRIPT_DIR/.. --namespace $NAMESPACE --timeout 1m0s --atomic --cleanup-on-fail --install --values $TEMPFILE

rm $TEMPFILE

ELB=$(kubectl get ingress -n $NAMESPACE | grep $HOSTNAME | awk '{print $3}')

echo ""
echo "${green}Success! Please add $HOSTNAME as a CNAME for $ELB in your DNS.${white}"
echo ""


