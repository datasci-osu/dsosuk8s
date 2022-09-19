#!/bin/bash

cat *.dockerfile > Dockerfile
../../scripts/docker_chain_build.sh .
