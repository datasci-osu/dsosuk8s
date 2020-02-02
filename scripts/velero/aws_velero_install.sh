#!/bin/bash

# exit if anything fails
set -e

SCRIPT_DIR=`dirname $0`

if [ $# -ne 4 ]; then
  echo "Usage: <aws_profile_name> <s3_bucket_name> <s3_region> <velero_secret_file>"
  echo ""
  echo "This script installs the Velero kubernetes backup tool in the current kubernetes cluster, with storage backed by an AWS S3 bucket."
  echo ""
  echo "This involves creating an S3 bucket, as well as an AWS velero IAM user, some associated policies, and a credentials file for that user which should be kept safe."
  echo ""
  echo "See https://github.com/vmware-tanzu/velero-plugin-for-aws#setup for details."
  echo ""
  echo "<aws_profile_name> is a valid AWS profile (usually in ~/.aws/credentials)"
  echo "<s3_bucket_name> is the name of the s3 bucket to create for backup storage (alphanumeric with . and - allowed)"
  echo "<s3_region> is a valid region where the bucket should be stored (e.g. us-west-2)"
  echo "<velero_secret_file> is the credentials file that the velero AWS"
  exit 1
fi


AWS_PROFILE=$1
BUCKET=$2
REGION=$3
CREDENTIALS_FILE=$4


aws s3api create-bucket \
    --bucket $BUCKET \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION



# create user
aws iam create-user --user-name velero

# create policy - needs to specify the bucket created
cat > velero-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                "ec2:DescribeSnapshots",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET}"
            ]
        }
    ]
}
EOF

# attach policies (from velero.json) to user
aws iam put-user-policy \
  --user-name velero \
  --policy-name velero \
  --policy-document file://velero-policy.json


# create access key, capture result, and parse it to produce the velero credentials file
res=$(aws iam create-access-key --user-name velero)
secretkey=$(echo $res | jq -r .AccessKey.SecretAccessKey)
keyid=$(echo $res | jq -r .AccessKey.AccessKeyId)


echo "[default]" > $CREDENTIALS_FILE
echo aws_access_key_id=$keyid >> $CREDENTIALS_FILE
echo aws_secret_access_key=$secretkey >> $CREDENTIALS_FILE

