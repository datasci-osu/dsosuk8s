#!/bin/bash

# allows tagging multistage builds 
# example Dockerfile (note that "as" and "TARGET" should match in the image name

# FROM ubuntu:18.04 as tools
# TARGET tools v0.0.1
# RUN apt-get install htop vim
#
# FROM tools as moretools
# TARGET moretools v0.0.1
# RUN apt-get install gnupg 

# docker_chain_build.sh . 

if [ $# != 1 ]; then
  echo "Usage: docker_chain_build.sh <PATH> # Dockerfile must exist in PATH, see script source for details" >&2
  exit 1
fi

DOCKERPATH=$1
cat ${DOCKERPATH}/Dockerfile | grep TARGET | awk -v dockerpath=${DOCKERPATH} '{print "sudo docker build --network=host --target " $3 " -t " $3 ":" $4 " " dockerpath}' | bash 

