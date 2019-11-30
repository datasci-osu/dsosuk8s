#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

$SCRIPT_DIR/docker_build_all.sh "$@"
$SCRIPT_DIR/docker_push_all.sh "$@"
