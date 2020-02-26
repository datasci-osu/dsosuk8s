#!/bin/bash

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0  settings.vars" 1>&2
  echo "Where settings.vars contains at least these vars:"
  echo "GRAFANA_PATH=grafana" 1>&2
  echo "CLUSTER_HOSTNAME=dev.your.edu" 1>&2
  echo "NAMESPACE=example-namespace" 1>&2
  echo "GRAFANA_APPNAME=example-grafana" 1>&2
  echo "KUBE_CONTEXT=devContext"
  echo "CLUSTER_HOSTNAME=dev.your.edu" 
  echo "" 1>&2
  echo "NAMESPACE should be the same namespace where prometheus is installed." 1>&2
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

validate_set GRAFANA_PATH "$GRAFANA_PATH" "^[[:alnum:]-]+$" required
validate_set CLUSTER_HOSTNAME "$CLUSTER_HOSTNAME" "^([[:alnum:]_-]+\.)*([[:alnum:]_-]+)$" required
validate_set STORAGE_CLASS "$STORAGE_CLASS" "^[[:alnum:]-]+$" required
validate_set STORAGE_CLASS "$STORAGE_CLASS" "^[[:alnum:]-]+$" required
validate_set NAMESPACE "$NAMESPACE" "^[[:alnum:]_-]+$" required
validate_set PROMETHEUS_APPNAME "$GRAFANA_APPNAME" "^[[:alnum:]_-]+$" required
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" required

kubectl config use-context $KUBE_CONTEXT


ADMIN_INIT_PASSWORD=$(wget "https://makemeapassword.ligos.net/api/v1/passphrase/plain?whenUp=StartOfWord&sp=F&pc=1&wc=2&sp=y&maxCh=20" -qO-)


# create namespace if it doesn't exist
echo "${yellow}Checking namespace... ${white}"
kubectl create namespace $NAMESPACE || true     # don't allow the set -e to take effect here
echo ""


echo "${yellow}Installing $GRAFANA_APPNAME ... ${white}"

TEMPFILE=$(mktemp) 
cat <<EOF > $TEMPFILE
adminPassword: $ADMIN_INIT_PASSWORD
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.org/mergeable-ingress-type: "minion"
    nginx.org/websocket-services: "grafana"
    #nginx.ingress.kubernetes.io/rewrite-target: /\$1
  path: /$GRAFANA_PATH/
  hosts:
    - $CLUSTER_HOSTNAME
  tls:
  - hosts:
    - $CLUSTER_HOSTNAME

persistence:
  enabled: true

grafana.ini:
  server:
    domain: $CLUSTER_HOSTNAME
    root_url: https://$CLUSTER_HOSTNAME/$GRAFANA_PATH
    serve_from_sub_path: true
  paths:
    data: /var/lib/grafana/data
    logs: /var/log/grafana
    plugins: /var/lib/grafana/plugins
    provisioning: /etc/grafana/provisioning
  analytics:
    check_for_updates: true
  log:
    mode: console
  grafana_net:
    url: https://grafana.net

nodeSelector:
  hub.jupyter.org/node-purpose: core 

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.$NAMESPACE.svc.cluster.local
      access: proxy
      isDefault: true  

plugins:
- digrich-bubblechart-panel
- grafana-clock-panel
- neocat-cal-heatmap-panel
- petrslavotinek-carpetplot-panel
- mtanda-histogram-panel
- michaeldmoore-multistat-panel
- natel-plotly-panel
- mxswat-separator-panel
- grafana-kubernetes-app
- devopsprodigy-kubegraf-app

EOF


helm upgrade $GRAFANA_APPNAME $SCRIPT_DIR/.. --namespace $NAMESPACE --timeout 5m0s --atomic --cleanup-on-fail --install --values $TEMPFILE

rm $TEMPFILE


echo ""
echo "${green}Success! Your admin username is ${blue}admin ${white}"
echo "${green}Your admin password is ${blue}${ADMIN_INIT_PASSWORD} ${white}"
echo "${green}Don't lose it! You might want to go change it immediately at ${blue}https://$CLUSTER_HOSTNAME/$GRAFANA_PATH ${white}"
echo ""


