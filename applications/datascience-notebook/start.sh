#!/bin/bash

set -e

echo "this script is a modification of the default jupyter-stack base-notebook start.sh; \
  we make the assumption the container is started as root; this pulls scripts
  from a github repo (just a subdir using svn) and calls out to them, which in turn
  do various user setup and NFS mounting."

  
