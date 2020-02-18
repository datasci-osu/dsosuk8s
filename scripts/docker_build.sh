#!/usr/bin/env bash

set -e 

if [[ $# != 1 ]]; then
  echo "Usage: docker_build.sh <directory_containing_dockerfile>"
  echo "Will only build if the image has changed (determined by md5summing the directory, sans the ops folder)"
  echo "Exits 0 if build not needed, 1 for error, 2 for built"
  exit 1
fi

TARGETDIR=$1


TAG=`find $TARGETDIR -type f -not -path "*/ops/*" -exec md5sum {} \; | grep -v -E '\.swp$' | sort -k 2 | md5sum | head -c 8`
# if ops/lasttag.txt doesn't exist, or it's contents are different from TAG, we need to rebuild and push. Otherwise we don't

IMAGENAME=`cat $TARGETDIR/image_name.txt`
echo -e "\e[33mChecking build $TARGETDIR, looking for tag $IMAGENAME:$TAG.\e[0m"


if [ ! -e $TARGETDIR/ops/build_options.txt ]; then 
  echo -e "\e[31mError: ops/build_options.txt for $TARGETDIR not found.. \e[0m"
  exit 1 
fi

if ! grep -q -E 'build:[[:blank:]+]true' $TARGETDIR/ops/build_options.txt; then
  echo -e "\e[31mbuild: true not set in ops/build_options.txt for $TARGETDIR, skipping. \e[0m"
  exit 0
fi

if ! grep -q "$TAG" <(docker image ls); then
  echo -e "\e[32mBuilding $IMAGENAME:$TAG.\e[0m"
  docker build -t $IMAGENAME:$TAG -f $TARGETDIR/Dockerfile $TARGETDIR
  for CUSTOMTAG in $(grep '^#TAG' $TARGETDIR/Dockerfile | awk '{print $2}'); do
    docker tag $IMAGENAME:$TAG $IMAGENAME:$CUSTOMTAG
  done
  docker tag $IMAGENAME:$TAG $IMAGENAME:latest
  echo -e "\e[32mBuilt $IMAGENAME:$TAG.\e[0m"
  exit 2
else
  echo -e "\e[31m$TARGETDIR present, not building. \e[0m"
  exit 0
fi

