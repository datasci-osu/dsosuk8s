#!/bin/bash

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

usage () {
  echo "Usage: $0  settings.vars" 1>&2
  echo "Where settings.vars contains at least these vars:"
  echo "VELERO_APPNAME=velero" 1>&2
  echo "EKS_CLUSTER_NAME=myCluster" 1>&2
  echo "VELERO_S3_BUCKET=my-s3bucket" 1>&2
  echo "VELERO_BACKUP_REGION=us-west-2" 1>&2
  echo "VELERO_CREDENTIALS_FILE=/path/to/my/creds.file" 1>&2
  echo "KUBE_CONTEXT=devContext" 1>&2
  echo "" 1>&2
  echo "Where creds.file is created by the velero aws install script." 1>&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

source $1

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))
SETTINGS_DIR=$(realpath $(dirname $1))

validate_set VELERO_APPNAME "$VELERO_APPNAME" "^[[:alnum:]_-]+$" required
validate_set EKS_CLUSTER_NAME "$EKS_CLUSTER_NAME" "^[[:alnum:]_-]+$" required
validate_set VELERO_S3_BUCKET "$VELERO_S3_BUCKET" "^[[:alnum:]_-]+$" required
validate_set VELERO_BACKUP_REGION "$VELERO_BACKUP_REGION" "^[[:alnum:]_-]+$" required
validate_set VELERO_CREDENTIALS_FILE "$VELERO_CREDENTIALS_FILE" "^.*$" required
validate_set KUBE_CONTEXT "$KUBE_CONTEXT" "^[[:alnum:]_-]+$" required

kubectl config use-context $KUBE_CONTEXT

NAMESPACE=velero


# create namespace if it doesn't exist
echo "${yellow}Checking namespace... ${white}"
kubectl create namespace $NAMESPACE || true     # don't allow the set -e to take effect here
echo ""


echo "${yellow}Installing $VELERO_APPNAME ... ${white}"

TEMPFILE=$(mktemp) 
cat <<EOF > $TEMPFILE
initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.0.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins

resources: 
  requests:
    memory: "128Mi"
    cpu: "250m"
  limits:
    memory: "256Mi"
    cpu: "500m"
nodeSelector:
  nodegroup-role: clustertools  

configuration:
  provider: aws
  backupStorageLocation:
    name: aws
    bucket: $VELERO_S3_BUCKET
    prefix: $EKS_CLUSTER_NAME
    config:
      region: $VELERO_BACKUP_REGION
  volumeSnapshotLocation: 
    name: aws
    config:
      region: $VELERO_BACKUP_REGION
  extraEnvVars:
    AWS_CLUSTER_NAME: $EKS_CLUSTER_NAME      
  logLevel: warning

EOF


helm upgrade $VELERO_APPNAME $SCRIPT_DIR/.. --namespace $NAMESPACE --set-file credentials.secretContents.cloud=$VELERO_CREDENTIALS_FILE --timeout 5m0s --atomic --cleanup-on-fail --install --values $TEMPFILE

rm $TEMPFILE


echo ""
echo "${green}Success! ${white}"
echo ""


