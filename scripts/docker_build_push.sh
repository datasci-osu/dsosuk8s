#!/usr/bin/env bash

if [ $# -ne 1 ]; then
  echo "Usage: docker_build_push.sh <directory_containing_dockerfile>"
  echo "Will only build and push if the image has changed (determined by md5summing the directory, sans the ops folder)"
fi

TARGETDIR=$1
TAG=`find $TARGETDIR -type f -not -path "*/ops/*" -exec md5sum {} \; | sort -k 2 | md5sum | head -c 8`
# if ops/lasttag.txt doesn't exist, or it's contents are different from TAG, we need to rebuild and push. Otherwise we don't
LASTTAG=`cat $TARGETDIR/ops/lasttag.txt`

if [ "$TAG" != "$LASTTAG" ]; then
  IMAGENAME=`cat $TARGETDIR/image_name.txt`

  docker build -t $IMAGENAME:$TAG -f $TARGETDIR/Dockerfile $TARGETDIR
  docker tag $IMAGENAME:$TAG $IMAGENAME:latest
  echo built $IMAGENAME:$TAG

  docker push $IMAGENAME
  echo pushed $IMAGENAME

  echo $TAG > $TARGETDIR/ops/lasttag.txt
else
  echo "$TARGETDIR unchanged, skipping."
fi
