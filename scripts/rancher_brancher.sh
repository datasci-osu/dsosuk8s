#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

if [ $# != 1 ]; then SCRIPT_DIR=`dirname $0`
  echo "Usage: rancher_brancher.sh <new_git_branch_name>"
  echo "This script does a number of things to speed up development of apps in Rancher:"
  echo " - checks out given git branch, creating if needed"
  echo " - does an initial push of the branch"
  echo " - opens the rancher context (project) chooser for creating a namespace in"
  echo " - creates a namespace based on the branch name"
  echo " - creates a new catalog entry based on the branch"
  echo " - notes the chosen context in $SCRIPT_DIR/rancher_brancher_context.txt and re-pushes"
  exit 1
fi

BRANCH=$1
PROJECT=$2

echo -e "\e[32mCreating git branch...\e[0m"
git checkout -b $BRANCH || git checkout $BRANCH

echo -e "\e[32mPushing branch...\e[0m"
git push --set-upstream origin $BRANCH

echo -e "\e[32mSelect Rancher Project for new namespace: \e[0m"
rancher context switch

echo -e "\e[32mCreating namespace...\e[0m"
rancher namespace create $BRANCH || rancher ls $BRANCH

echo -e "\e[32mAdding catalog...\e[0m"
URL=$(git config --get remote.origin.url)
rancher catalog add --branch $BRANCH catalog-$BRANCH $URL || echo "Catalog already exists"

echo -e "\e[32mNoting chosen context in $SCRIPT_DIR/rancher_brancher_context.txt...\e[0m"
echo $(rancher context current) > $SCRIPT_DIR/rancher_brancher_context.txt

echo -e "\e[32mRe-pushing...\e[0m"
git push


