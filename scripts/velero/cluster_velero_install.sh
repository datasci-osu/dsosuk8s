#!/bin/bash

# exit if anything fails
set -e

SCRIPT_DIR=`dirname $0`

if [ $# -ne 3 ]; then
  echo "Usage: <s3_bucket_name> <s3_region> <velero_secret_file>"
  echo ""
  echo "This script installs the Velero kubernetes backup tool in the current kubernetes cluster, assuming AWS assets exist (created by aws_velero_install.sh), including the secret velero user credential file."
  echo ""
  exit 1
fi


BUCKET=$1
REGION=$2
CREDENTIALS_FILE=$3

if [ ! -f $CREDENTIALS_FILE ]; then
  echo "Error, cannot find credentials file $CREDENTIALS_FILE. Exiting."
  exit 1
fi

kubecluster=$(kubectl config current-context)
echo -n -e "Installing velero into kubernetes context/cluster $kubecluster, type 'yes' to proceed: "
read answer
if [ $answer != "yes" ]; then
  echo "Ok, existing."
  exit 1
fi


if ! which velero > /dev/null; then
  echo ""
  echo "cannot find velero, is it installed and in your PATH?"
  exit 1
fi

velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.0.0 \
    --bucket $BUCKET \
    --backup-location-config region=$REGION \
    --snapshot-location-config region=$REGION \
    --secret-file $CREDENTIALS_FILE


