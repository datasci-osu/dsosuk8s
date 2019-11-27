#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

# a trick to get the name of the folder containing this script (DIRNAME is dev-demo-singleuser-nfs)
DIRPATH=`dirname $(readlink -f $0)`
DIRNAME=`basename $DIRPATH`

# the build and push step assume docker is running locally for building, and that
# we're logged into dockerhub (with `docker login`). docker_build.sh checks to see 
# if the image needs rebuilding based on md5sum of the directory; if so it rebuilds
# and exits 1; this then triggers a push to dockerhub (which also checks to see if
# that image is present already based on it's tag, which is based on the md5sum)

# build image, if triggered a build, also trigger a push
# do both the base-notebook and the nfsserver since working on both
# using paths relative to $SCRIPT_DIR rather than the pwd of the caller
if $SCRIPT_DIR/../../scripts/docker_build.sh $SCRIPT_DIR/../../applications/base-notebook; then
  $SCRIPT_DIR/../../scripts/docker_push.sh $SCRIPT_DIR/../../applications/base-notebook
fi

# same thing if the drive image changed, in which case we also need to redeploy the helm chart
# (so delete it here)
if $SCRIPT_DIR/../../scripts/docker_build.sh $SCRIPT_DIR/../../applications/nfsserver3; then
  $SCRIPT_DIR/../../scripts/docker_push.sh $SCRIPT_DIR/../../applications/nfsserver3
  helm delete --purge nfsdrive-$DIRNAME
fi


# create a namespace if needed to work in, based on the folder name this test is in; 
# create a yaml def and send it to kubectl apply so
# no warning is created if it already exists
kubectl create namespace $DIRNAME --dry-run -o yaml | kubectl apply -f -

# if a drive is not running, start one (but don't wait on helm upgrade to do nothing, too slow,
# instead just check to see if one is already running)
# name the release with the dirname as well since helm release names must be unique cluster-wide
if ! kubectl get pods -n $DIRNAME | grep -E ".nfsdrive-$DIRNAME.*Running.*"; then
  # setting namespace probably not necessary (since helm releases aren't really namespaced), but shouldn't hurt
  helm upgrade nfsdrive-$DIRNAME $SCRIPT_DIR/../../charts/drive/v0.8/ \
	--install \
	--namespace $DIRNAME \
	--set size=2Gi \
	--wait
fi


# update configmap based on testing start.sh and mount_home_nfs.sh
# the pod definition mounts the configmaps to the right location in the filesystem - this way 
# we don't have to rebuild/repush/repull the image every time
kubectl create configmap --dry-run start --from-file=./start.sh --output yaml | kubectl apply -n $DIRNAME -f - 
kubectl create configmap --dry-run mount-nfs --from-file=./mount_nfs.sh --output yaml | kubectl apply -n $DIRNAME -f -

# delete and recreate pod to get the new configmaps 
# (it may be enough to just apply, but in case something changed in the singleuser_pod.yaml
# isn't updateable a full delete/recreate will still work)
kubectl delete -f singleuser_pod.yaml -n $DIRNAME --wait
# set the entry for the environement variable to be the one determined by the helm chart 
# kubectl apply doesn't support dynamically setting environment variables, hence the sed | kubectl hack
cat singleuser_pod.yaml | sed -r "s/nfsdrive/nfsdrive-$DIRNAME/" | kubectl apply -f - -n $DIRNAME --wait

echo -e "\e[32mUpdated. You may want to keep track of the container status:\e[0m"
echo -e "\e[33mwatch kubectl logs pod/singleuser-pod -n $DIRNAME\e[0m"
echo -e "\e[33mwatch kubectl get all -n $DIRNAME\e[0m"
echo ""
echo -e "\e[32mOr get a shell to the pod\e[0m"
echo -e "\e[33mkubectl exec -it pod/singleuser-pod -n $DIRNAME bash\e[0m"
echo ""
echo -e "\e[32mOr, if the notebook server is running, access it via port-forwarding:\e[0m"
echo -e "\e[33mkubectl port-forward pod/singleuser-pod 8888:8888 -n $DIRNAME\e[0m"
echo -e "\e[32mAnd then follow the link provided by kubectl logs (http://127.0.0.1:8888/?token=f7154d...)\e[0m"

