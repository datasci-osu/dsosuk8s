#!/bin/bash

# allows pushing tagged multistage builds 
# example Dockerfile (note that "as" and "TARGET" should match in the image name

# FROM ubuntu:18.04 as tools
# TARGET tools v0.0.1
# RUN apt-get install htop vim
#
# FROM tools as moretools
# TARGET moretools v0.0.1
# RUN apt-get install gnupg 

# docker_chain_push.sh . 

if [ $# != 1 ]; then
  echo "Usage: docker_chain_push.sh <PATH> # Dockerfile must exist in PATH, see script source for details" >&2
  exit 1
fi

if ! grep -q -E '"experimental"[[:blank:]]*:[[:blank:]]*"enabled"' ~/.docker/config.json; then
  echo 'Error: "experimental": "enabled" must be set in ~/.docker/config.json (to check for already existing images)'
  exit 1
fi

read -p "DockerHub Username: " DOCKERUSER
read -sp "DockerHub Password: " DOCKERPASS

docker login -u ${DOCKERUSER} -p ${DOCKERPASS}

DOCKERPATH=$1
cat ${DOCKERPATH}/Dockerfile | grep TARGET | while read -r line; do
  linearray=($line)
  IMAGENAME=${linearray[2]}
  TAG=${linearray[3]}

  if ! docker manifest inspect $IMAGENAME:$TAG > /dev/null 2> /dev/null; then
    echo Running: docker tag $IMAGENAME:$TAG $DOCKERUSER/$IMAGENAME:$TAG
    docker tag $IMAGENAME:$TAG $DOCKERUSER/$IMAGENAME:$TAG
    echo Running: docker push $DOCKERUSER/$IMAGENAME:$TAG
    docker push $DOCKERUSER/$IMAGENAME:$TAG
    echo -e "\e[32mPushed $IMAGENAME:$TAG. \e[0m"
  else
    echo -e "\e[31m$IMAGE:$TAG already present, not pushing. \e[0m"
    exit 0
  fi

done

exit 0



