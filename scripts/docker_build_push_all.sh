#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

#$SCRIPT_DIR/docker_build_all.sh "$@"
#$SCRIPT_DIR/docker_push_all.sh "$@"

set -e

DIRLIST=$(find $SCRIPT_DIR/../docker_images/ -maxdepth 1 -mindepth 1 )

for DIR in $DIRLIST; do
  # build exits 1 if it fails, so we won't push and instead we'll just quit altogether (set -e above)
  $SCRIPT_DIR/docker_build.sh $DIR
  if [ $? == 0 ]; then
    $SCRIPT_DIR/docker_push.sh $DIR
  fi
  echo ""

done
