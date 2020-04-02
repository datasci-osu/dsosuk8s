#!/bin/bash 

set -e

GIT_ROOT=$(git rev-parse --show-toplevel)
source $GIT_ROOT/scripts/utils.src

cd $GIT_ROOT/docs/build

for chart in $(ls -1 $GIT_ROOT/charts); do
  helm lint $GIT_ROOT/charts/$chart
  created=$(basename $(helm package $GIT_ROOT/charts/$chart | grep Successfully | awk '{print $NF}'))
  # we don't md5sum the package itself due to https://github.com/helm/helm/issues/3612
  # so the md5sum-dir function from utils.src recursively md5s a directory 
  md5sum-dir $chart > $created.md5sum-dir

  if [ -f ../$created.md5sum-dir ]; then
    if [ $(cat $created.md5sum-dir) == $(cat ../$created.md5sum-dir) ]; then
      echo "${yellow}Release $created unchanged, not added to repo. ${white}"
      rm -f $changed
      rm -f $changed.md5sum-dir
    else
      echo "${red}Release $created changed, overwriting old version in repo. ${white}"
      mv $created ..
      mv $created.md5sum-dir ..
    fi
  else
    echo "${green}Added new release $created to repo. ${white}"
    mv $created ..
    mv $created.md5sum-dir ..
  fi
done

echo "${green}Removing build artefacts...${white}"
rm -f ./*.tgz
rm -f ./*.tgz.md5sum-dir

cd ..
echo "${yellow}Building index.yaml ${white}"
helm repo index .



