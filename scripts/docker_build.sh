#!/usr/bin/env bash

set -e 

if [[ $# != 1 ]]; then
  echo "Usage: docker_build.sh <directory_containing_dockerfile>"
  echo "Will only build if the image has changed (determined by md5summing the directory, sans the ops folder)"
  echo "Exits 0 if build not needed or build succeeded, 1 for error"
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

echo -e "\e[33mChecking build $TARGETDIR, looking for tag $IMAGENAME:$TAG.\e[0m"


if ! grep -q "$TAG" <(docker image ls); then
  echo -e "\e[32mBuilding $IMAGENAME:$TAG.\e[0m"
  docker build -t $IMAGENAME:$TAG -f $TARGETDIR/Dockerfile $TARGETDIR
  for CUSTOMTAG in $(grep '^#TAG' $TARGETDIR/Dockerfile | awk '{print $2}'); do
    echo "Tagging: tag $IMAGENAME:$TAG $IMAGENAME:$CUSTOMTAG"
    docker tag $IMAGENAME:$TAG $IMAGENAME:$CUSTOMTAG
  done
  docker tag $IMAGENAME:$TAG $IMAGENAME:latest
  echo -e "\e[32mBuilt $IMAGENAME:$TAG.\e[0m"
  exit 0
else
  echo -e "\e[31m$TARGETDIR present, not building. \e[0m"
  exit 0
fi

