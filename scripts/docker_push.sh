#!/usr/bin/env bash

if [ $# -ne 1 ]; then
  echo "Usage: docker_push.sh <directory_containing_dockerfile>"
fi

TARGETDIR=$1
IMAGENAME=`cat $TARGETDIR/image_name.txt`

docker push $IMAGENAME
echo pushed $IMAGENAME
