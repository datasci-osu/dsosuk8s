#!/usr/bin/env bash

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src
SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))

find $GIT_ROOT/docker_images -maxdepth 1 -mindepth 1 -exec $SCRIPT_DIR/docker_push.sh {} \;
