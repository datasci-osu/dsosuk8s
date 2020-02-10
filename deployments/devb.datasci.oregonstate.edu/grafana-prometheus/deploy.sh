#!/bin/bash
set -e

#############################
# These you'll want to set
#############################

ADMIN_INIT_PASSWORD=admin
GRAFANA_PATH=grafana        # should not begin or end with /, those will be added (e.g. some/path -> /some/path/)

#############################
# These less so
#############################

NAMESPACE=monitoring
STORAGE_CLASS=gp2
PROMETHEUS_APPNAME=prometheus
GRAFANA_APPNAME=grafana

SCRIPT_DIR=$(dirname $0)
PROMETHEUS_CHART=$SCRIPT_DIR/../../../charts/prometheus
GRAFANA_CHART=$SCRIPT_DIR/../../../charts/grafana

##########################
# dirty work happens below
##########################

black="$(tput setaf 0)"
red="$(tput setaf 1)"
green="$(tput setaf 2)"
yellow="$(tput setaf 3)"
blue="$(tput setaf 4)"
magenta="$(tput setaf 5)"
cyan="$(tput setaf 6)"
white="$(tput setaf 7)"



SCRIPT_DIR=$(dirname $0)
HOSTNAME=$(cat $SCRIPT_DIR/../cluster-ingress-hostname)
KUBECONTEXT=$(cat $SCRIPT_DIR/../kube-context)

kubectl config use-context $KUBECONTEXT


cat <<EOF > 1-prometheus.yaml 
pushgateway:
  nodeSelector:
    hub.jupyter.org/node-purpose: core
kubeStateMetrics:
  nodeSelector:
    hub.jupyter.org/node-purpose: core
alertmonitor:
  nodeSelector:
    hub.jupyter.org/node-purpose: core
alertmanager:
  persistentVolume:
    storageClass: $STORAGE_CLASS
  nodeSelector:
    hub.jupyter.org/node-purpose: core
server:
  persistentVolume:
    storageClass: $STORAGE_CLASS
  nodeSelector:
    hub.jupyter.org/node-purpose: core
EOF



cat <<EOF > 2-grafana.yaml
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
    - $HOSTNAME
  tls:
  - hosts:
    - $HOSTNAME

grafana.ini:
  server:
    domain: $HOSTNAME
    root_url: https://$HOSTNAME/$GRAFANA_PATH
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




cat <<EOF > 1-create-prometheus.sh
#!/bin/bash
SCRIPT_DIR=$(dirname $0)
HOSTNAME=$(cat $SCRIPT_DIR/../cluster-ingress-hostname)
KUBECONTEXT=$(cat $SCRIPT_DIR/../kube-context)

kubectl config use-context $KUBECONTEXT
helm upgrade $PROMETHEUS_APPNAME $PROMETHEUS_CHART --namespace $NAMESPACE --atomic --cleanup-on-fail --install --values 1-prometheus.yaml
EOF

chmod u+x 1-create-prometheus.sh


cat <<EOF > 2-create-grafana.sh
#!/bin/bash
helm upgrade $GRAFANA_APPNAME $GRAFANA_CHART --namespace $NAMESPACE --atomic --cleanup-on-fail --install --values 2-grafana.yaml
EOF

chmod u+x 2-create-grafana.sh



cat <<EOF > status.sh
#!/bin/bash
black="\$(tput setaf 0)"
red="\$(tput setaf 1)"
green="\$(tput setaf 2)"
yellow="\$(tput setaf 3)"
blue="\$(tput setaf 4)"
magenta="\$(tput setaf 5)"
cyan="\$(tput setaf 6)"
white="\$(tput setaf 7)"

SCRIPT_DIR=$(dirname $0)
HOSTNAME=$(cat $SCRIPT_DIR/../cluster-ingress-hostname)
KUBECONTEXT=$(cat $SCRIPT_DIR/../kube-context)

kubectl config use-context $KUBECONTEXT

echo "\${yellow}Helm release list: \${white}"
helm list --namespace $NAMESPACE
echo ""

echo "\${yellow}Kubernetes resources:\${white}"
kubectl get all --namespace $NAMESPACE
echo ""

echo "\${yellow}Kubernetes PVCs:\${white}"
kubectl get pvc --namespace $NAMESPACE
echo ""

echo "\${yellow}Kubernetes PVs:\${white}"
kubectl get pv | grep -E "[[:blank:]]($NAMESPACE)\/"
echo ""E

EOF

chmod u+x status.sh



cat <<EOF > teardown.sh
#!/bin/bash

black="\$(tput setaf 0)"
red="\$(tput setaf 1)"
green="\$(tput setaf 2)"
yellow="\$(tput setaf 3)"
blue="\$(tput setaf 4)"
magenta="\$(tput setaf 5)"
cyan="\$(tput setaf 6)"
white="\$(tput setaf 7)"

SCRIPT_DIR=$(dirname $0)
HOSTNAME=$(cat $SCRIPT_DIR/../cluster-ingress-hostname)
KUBECONTEXT=$(cat $SCRIPT_DIR/../kube-context)

kubectl config use-context $KUBECONTEXT

echo "\${red}Warning: This will delete all data for $PROMETHEUS_APPNAME and $GRAFANA_APPNAME. \${white}"

echo -n "\${yellow}Type the NAMESPACE ($NAMESPACE) to continue: \${white}"
read CHECKNAME
if [ \${CHECKNAME} != $NAMESPACE ]; then
  echo "No match, exiting."
  exit 1
fi

echo -n "Ok, removing in ";
for i in \$(seq 5 1); do
  echo -n "\$i... "
  sleep 1
done
echo ""
echo ""

echo "\${yellow}Deleting grafana resources... \${white}"
echo "\${magenta}helm delete $GRAFANA_APPNAME --namespace $NAMESPACE \${white}"
helm delete $GRAFANA_APPNAME --namespace $NAMESPACE
echo ""

echo "\${yellow}Deleting prometheus resources... \${white}"
echo "\${magenta}helm delete $PROMETHEUS_APPNAME --namespace $NAMESPACE \${white}"
helm delete $PROMETHEUS_APPNAME --namespace $NAMESPACE
echo ""


echo "\${yellow}Deleting namespace... \${white}"
echo "\${magenta}kubectl delete namespace $NAMESPACE \${white}"
kubectl delete namespace $NAMESPACE
echo ""

EOF

chmod u+x teardown.sh




####
# do iiiiit
####


echo "${red}Warning: this can take a couple of minutes. "
echo "Killing (with e.g. Ctrl-C) may leave things in an inconsistent state."
echo "Only do so if needed and after several minutes' wait. ${white}"
echo ""
sleep 2

# create namespace if it doesn't exist
echo "${yellow}Checking namespace: ${white}"
kubectl create namespace $NAMESPACE || true     # don't allow the set -e to take effect here
echo ""

echo "${yellow}Running 1-create-prometheus.sh...${white}"
./1-create-prometheus.sh
echo ""

echo "${yellow}Running 2-create-grafana.sh...${white}"
./2-create-grafana.sh
echo ""

echo "${green}Finished! Your monitoring setup is at ${blue}https://$HOSTNAME/$GRAFANA_PATH ${white}"

