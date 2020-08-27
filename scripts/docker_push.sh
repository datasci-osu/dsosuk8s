#!/usr/bin/env bash

# set "experimental" : "enabled" in ~/.docker/config.json

set -e 

if [[ ( $# != 1 ) && ( $# != 2 ) ]]; then
  echo "Usage: docker_push.sh <directory_containing_dockerfile>"
  echo "Will only push if the image tag (determined by md5summing the directory, sans the ops folder) is not present."
  echo "Exits 1 for error, 0 for push not needed or successful push."
  exit 1
fi

if ! grep -q -E '"experimental"[[:blank:]]*:[[:blank:]]*"enabled"' ~/.docker/config.json; then
  echo 'Error: "experimental": "enabled" must be set in ~/.docker/config.json (to check for already existing images)'
  exit 1
fi

TARGETDIR=$1
# determine tag as md5sum of files in directory (not git hash, which updates more frequently than images)
TAG=`find $TARGETDIR -type f -exec md5sum {} \; | grep -v -E '\.swp$' | sort -k 2 | md5sum | head -c 8`

IMAGENAME=$(grep '^#IMAGE' $TARGETDIR/Dockerfile | awk '{print $2}')

if [ "$IMAGENAME" == "" ]; then
  echo "This script assumes the Dockerfile contains comments e.g. #IMAGE owner/imagename and #TAG v0.0.1 (multiple tag lines allowed)." 1>&2
  exit 1
fi


echo -e "\e[33mChecking push $TARGETDIR, looking for $IMAGENAME:$TAG.\e[0m"


# check for image:tag on dockerhub with docker manifest inspect
if ! docker manifest inspect $IMAGENAME:$TAG > /dev/null 2> /dev/null; then
  docker push $IMAGENAME | cat       # be quiet about it, sheesh; edit, why doesn't this work per https://github.com/moby/moby/issues/37417#issuecomment-403833610 
  echo -e "\e[32mPushed $IMAGENAME. \e[0m"
  exit 0
else
  echo -e "\e[31m$TARGETDIR already present, not pushing. \e[0m"
  exit 0
fi

