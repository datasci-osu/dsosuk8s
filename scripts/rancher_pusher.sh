#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

BRANCH=$(git rev-parse --abbrev-ref HEAD)

BRANCH_CONTEXT=$(cat $SCRIPT_DIR/rancher_brancher_context.txt)
CURRENT_CONTEXT=$(rancher context current)

if [ "$BRANCH_CONTEXT" != "$CURRENT_CONTEXT" ]; then
  echo -e "\e[31m WARNING: The current rancher context is not the context the corresponding namespace was created in, be careful.\e[0m"
fi

echo -e "\e[32mRunning git push...\e[0m"
git push

echo -e "\e[32mRefreshing Rancher catalog\e[0m"
rancher catalog refresh catalog-$BRANCH
