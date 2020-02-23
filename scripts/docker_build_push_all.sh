#!/usr/bin/env bash

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src
SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))


DIRLIST=$(find $GIT_ROOT/docker_images/ -maxdepth 1 -mindepth 1 )

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
