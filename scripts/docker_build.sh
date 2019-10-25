#!/usr/bin/env bash

if [ $# -ne 1 ]; then
  echo "Usage: docker_build.sh <directory_containing_dockerfile>"
fi

TARGETDIR=$1
TAG=`find $TARGETDIR -type f -not -path "$TARGETDIR/ops/*" -exec md5sum {} \; | sort -k 2 | md5sum | head -c 8`
IMAGENAME=`cat $TARGETDIR/image_name.txt`

docker build -t $IMAGENAME:$TAG -f $TARGETDIR/Dockerfile $TARGETDIR
docker tag $IMAGENAME:$TAG $IMAGENAME:latest
echo built $IMAGENAME:$TAG
