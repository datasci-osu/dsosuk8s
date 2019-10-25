#!/usr/bin/env bash

if [ $# -ne 1 ]; then
  echo "Usage: pull_resources.sh <directory_containing_dockerfile>"
fi

TARGETDIR=$1
$TARGETDIR/ops/pull_resources.sh
