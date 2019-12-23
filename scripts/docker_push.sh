#!/usr/bin/env bash

# set "experimental" : "enabled" in ~/.docker/config.json

set -e 

if [[ ( $# != 1 ) && ( $# != 2 ) ]]; then
  echo "Usage: docker_push.sh <directory_containing_dockerfile>"
  echo "Will only push if the image tag (determined by md5summing the directory, sans the ops folder) is not present."
  exit
fi

if ! grep -q '"experimental": "enabled"' ~/.docker/config.json; then
  echo 'Error: "experimental": "enabled" must be set in ~/.docker/config.json (to check for already existing images)'
  exit
fi

TARGETDIR=$1
TAG=`find $TARGETDIR -type f -not -path "*/ops/*" -exec md5sum {} \; | sort -k 2 | md5sum | head -c 8`
# if ops/lasttag.txt doesn't exist, or it's contents are different from TAG, we need to rebuild and push. Otherwise we don't
IMAGENAME=`cat $TARGETDIR/image_name.txt`

echo -e "\e[33mChecking push $TARGETDIR, looking for $IMAGENAME:$TAG.\e[0m"

if [ ! -e $TARGETDIR/ops/build_options.txt ]; then 
  echo -e "\e[31mError: ops/build_options.txt for $TARGETDIR not found.. \e[0m"
  exit 1
fi

if ! grep -q -E 'push:[[:blank:]+]true' $TARGETDIR/ops/build_options.txt; then
  echo -e "\e[31mbuild: push not set in ops/build_options.txt for $TARGETDIR, skipping. \e[0m"
  exit 0
fi

# check for image:tag on dockerhub with docker manifest inspect
if ! docker manifest inspect $IMAGENAME:$TAG > /dev/null 2> /dev/null; then
  docker push $IMAGENAME | cat       # be quiet about it, sheesh; edit, why doesn't this work per https://github.com/moby/moby/issues/37417#issuecomment-403833610 
  echo -e "\e[32mPushed $IMAGENAME. \e[0m"
else
  echo -e "\e[31m$TARGETDIR already present, not pushing. \e[0m"
fi

