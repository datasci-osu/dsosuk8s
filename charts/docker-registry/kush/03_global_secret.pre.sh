
CREATE_GLOBAL_SECRETNAME=$(index "createGlobalSecret.secretName" "")


# this is a fork of the ClusterImage github repo with some bugfixes,
# should replace with official repo (version-pinned) when they are pulled in
REPO="https://github.com/datasci-osu/ClusterSecret.git"
FOLDER="ClusterSecret"
BRANCH="withimage"

if [ "$CREATE_GLOBAL_SECRETNAME" != "" ]; then
  echo "${yellow}Adding cluster secret, installing ClusterSecret Operator from $REPO (branch $BRANCH) ${white}" 1>&2
  git clone --single-branch --branch $BRANCH $REPO $CHART_DIR/$FOLDER
  kubectl apply -f $CHART_DIR/$FOLDER/yaml --context $HELM_KUBECONTEXT

  HOSTNAME=$(index 'ingress.hosts[0]' '')
  if [ "$HOSTNAME" == "" ]; then
    echo "${red}You must set an ingress.hosts entry in your --values.${white}" 1>&2
    exit 1
  fi
  SECRET_DATA=$( kubectl create secret docker-registry $RELEASE_NAME --docker-server $HOSTNAME --docker-username $ADMIN_USERNAME --docker-password $ADMIN_PASSWORD -o yaml --dry-run=client | yq r - data )
  echo "${cyan}$SECRET_DATA${white}"


cat << EOF | kubectl apply -f -
apiVersion: clustersecret.io/v1
kind: ClusterSecret
metadata:
  name: $RELEASE_NAME-global-regcred
  labels:
    somelabel: somevalue
  annotations:
    someannotation: somevalue
matchNamespace:
  - '.*'
avoidNamespaces:
  - 'default'
type: kubernetes.io/dockerconfigjson
# as output in kubectl create secret docker-registry regkey --docker-server my.docker.registry --docker-username adminuser --docker-password adminpass -o yaml --dry-run
data:
  $SECRET_DATA

EOF


fi
