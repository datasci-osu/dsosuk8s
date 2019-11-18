#!/usr/bin/env bash

if [[ ($# -ne 1) || ($# -ne 2 ) ]]; then
  echo "Usage: docker_build.sh <directory_containing_dockerfile>"
  echo "Will only build if the image has changed (determined by md5summing the directory, sans the ops folder)"
fi

TARGETDIR=$1

CONTEXT="local"
if [[ ! -z "$2" ]]; then
  CONTEXT=$2
fi

TAG=`find $TARGETDIR -type f -not -path "*/ops/*" -exec md5sum {} \; | sort -k 2 | md5sum | head -c 8`
# if ops/lasttag.txt doesn't exist, or it's contents are different from TAG, we need to rebuild and push. Otherwise we don't
LASTTAG_BUILT=`cat $TARGETDIR/ops/lasttag_built_$CONTEXT.txt`
IMAGENAME=`cat $TARGETDIR/image_name.txt`

if [ "$TAG" != "$LASTTAG_BUILT" ]; then

  docker build -t $IMAGENAME:$TAG -f $TARGETDIR/Dockerfile $TARGETDIR
  docker tag $IMAGENAME:$TAG $IMAGENAME:latest
  echo built $IMAGENAME:$TAG

  echo $TAG > $TARGETDIR/ops/lasttag_built_$CONTEXT.txt
else
  echo "$TARGETDIR unchanged, not building."
fi

