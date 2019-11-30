#!/usr/bin/env bash

if [[ $# != 1 ]]; then
  echo "Usage: docker_build.sh <directory_containing_dockerfile>"
  echo "Will only build if the image has changed (determined by md5summing the directory, sans the ops folder)"
  exit
fi

TARGETDIR=$1


TAG=`find $TARGETDIR -type f -not -path "*/ops/*" -exec md5sum {} \; | sort -k 2 | md5sum | head -c 8`
# if ops/lasttag.txt doesn't exist, or it's contents are different from TAG, we need to rebuild and push. Otherwise we don't

IMAGENAME=`cat $TARGETDIR/image_name.txt`
echo -e "\e[33mChecking build $TARGETDIR, looking for tag $IMAGENAME:$TAG.\e[0m"

if ! grep -q -E 'build:[[:blank:]+]true' $TARGETDIR/ops/build_options.txt; then
  echo -e "\e[31mbuild: true not set in ops/build_options.txt for $TARGETDIR, skipping. \e[0m\n"
  exit 1
fi

if ! grep -q "$TAG" <(docker image ls); then
  echo -e "\e[32mBuilding $IMAGENAME:$TAG.\e[0m"
  docker build -t $IMAGENAME:$TAG -f $TARGETDIR/Dockerfile $TARGETDIR
  docker tag $IMAGENAME:$TAG $IMAGENAME:latest
  echo -e "\e[32mBuilt $IMAGENAME:$TAG.\e[0m\n"
else
  echo -e "\e[31m$TARGETDIR present, not building. \e[0m\n"
  exit 1
fi

