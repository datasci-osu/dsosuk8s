#!/bin/bash
set -e

#############################
# These you'll want to set
#############################
APPNAME=ex2
HOMEDRIVE_SIZE=4Gi
ADMIN_USERS="oneils, smithj"

MEM_GUARANTEE=0.5G
MEM_LIMIT=1G
CPU_GUARANTEE=0.1
CPU_LIMIT=1

# can be native, lti, or dummy
AUTH_TYPE=native
NUM_PLACEHOLDERS=0

#########################
# these less so
#########################
HOSTNAME=devb.datasci.oregonstate.edu
BASE_URL="/$APPNAME/"
HOMEDRIVE_APPNAME="homedrive-$APPNAME"
HUB_APPNAME="hub-$APPNAME"
NAMESPACE=$APPNAME

SCRIPT_DIR=$(dirname $0)
DRIVE_CHART=$SCRIPT_DIR/../../charts/drive/latest
HUB_CHART=$SCRIPT_DIR/../../charts/ds-jupyterlab/latest


##########################
# dirty work happens below
##########################

source ../colors.sh

cat <<EOF > 1-drive.yaml
size: $HOMEDRIVE_SIZE
EOF

cat <<EOF > 2-hub.yaml
jupyterhub:
  hub:
    extraEnv:
      AUTH_TYPE: $AUTH_TYPE                               # native, lti, or dummy
      LTI_CLIENT_KEY: $(openssl rand -hex 32)         # used if using LTI auth
      LTI_CLIENT_SECRET: $(openssl rand -hex 32)
      ADMIN_USERS: "$ADMIN_USERS"
    baseUrl: "$BASE_URL"   # must start and end with a /

  scheduling:
    userPlaceholder:
      enabled: true
      replicas: $NUM_PLACEHOLDERS

  cull:
    enabled: true
    timeout: 3600        # cull inactive servers after this long
    maxAge: 28800        # cull servers this old, even if active (0 disables)

  proxy:
    secretToken: $(openssl rand -hex 32)

  singleuser:
    # looks like these should be set null to delete the key (including those defaulted in the jupyterhub chart) for the c.Spawner limits below to be used
    memory:
      limit: "$MEM_LIMIT"
      guarantee: "$MEM_GUARANTEE"
    cpu:
      limit: $CPU_LIMIT
      guarantee: $CPU_GUARANTEE
    image:
      name: oneilsh/ktesting-datascience-notebook
      tag: "1d47a65a" 
    defaultUrl: "/lab"

    extraEnv:
      NFS_SVC_HOME: $HOMEDRIVE_APPNAME   # same as above

    uid: 0
    fsGid: 0

  ingress:
    hosts:
    - $HOSTNAME
    tls:
    - hosts:
      - $HOSTNAME
EOF


echo "#!/bin/bash" > 1-create-drive.sh
echo "helm upgrade $HOMEDRIVE_APPNAME $DRIVE_CHART --namespace $NAMESPACE --atomic --cleanup-on-fail --install --values 1-drive.yaml" >> 1-create-drive.sh
chmod u+x 1-create-drive.sh

echo "#!/bin/bash" > 2-create-hub.sh
echo "helm upgrade $HUB_APPNAME $HUB_CHART --namespace $NAMESPACE --atomic --cleanup-on-fail --install --values 2-hub.yaml" >> 2-create-hub.sh
chmod u+x 2-create-hub.sh

echo "#!/bin/bash" > status.sh
echo "source ../colors.sh" >> status.sh
echo 'echo $green Helm chart list:$white' >> status.sh
echo "helm list --namespace $NAMESPACE" >> status.sh
echo "echo ''" >> status.sh
echo 'echo $green Kubernetes resources:$white' >> status.sh
echo "kubectl get all --namespace $NAMESPACE" >> status.sh
echo "echo ''" >> status.sh
echo 'echo $green Kubernetes PVCs:$white' >> status.sh
echo "kubectl get pvc --namespace $NAMESPACE" >> status.sh
echo "echo ''" >> status.sh
echo 'echo $green Kubernetes PVs:$white' >> status.sh
echo "kubectl get pv | grep -E \"[[:blank:]]$NAMESPACE\/\"" >> status.sh
chmod u+x status.sh

####
# do iiiiit
####


# create namespace if it doesn't exist
echo "$yellow Checking namespace: $white"
kubectl create namespace $NAMESPACE || true     # don't allow the set -e to take effect here
echo ""

echo "$yellow Running 1-create-drive.sh...$white"
./1-create-drive.sh
echo ""

echo "$yellow Running 2-create-hub.sh...$white"
./2-create-hub.sh
echo ""

echo "$green Finished! Your hub is at $blue https://$HOSTNAME$BASE_URL $white"
