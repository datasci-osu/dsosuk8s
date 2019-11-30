#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

find $SCRIPT_DIR/../applications -maxdepth 1 -mindepth 1 -exec $SCRIPT_DIR/docker_push.sh {} \;
