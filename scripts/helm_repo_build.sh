#!/bin/bash 

set -e

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

cd $GIT_ROOT/docs

for chart in $(ls -1 $GIT_ROOT/charts); do
  echo "${green}Building $chart ${white}"
  helm lint $GIT_ROOT/charts/$chart
  helm package $GIT_ROOT/charts/$chart
done


echo "${green}Building index.yaml ${white}"
helm repo index .



