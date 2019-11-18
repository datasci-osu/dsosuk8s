#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

$SCRIPT_DIR/build_all.sh "$@"
$SCRIPT_DIR/push_all.sh "$@"
