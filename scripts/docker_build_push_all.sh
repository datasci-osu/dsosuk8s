#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`


DIRLIST=$(find $SCRIPT_DIR/../docker_images/ -maxdepth 1 -mindepth 1 )

for DIR in $DIRLIST; do
  # returns 2 for built, 1 for fail, 0 for build not needed
  $SCRIPT_DIR/docker_build.sh $DIR
  RES=$?
  if [ $RES == 2 ]; then
    $SCRIPT_DIR/docker_push.sh $DIR
  elif [ $RES == 1 ]; then
    exit 2
  fi
  echo ""

done
