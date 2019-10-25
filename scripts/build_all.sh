#!/usr/bin/env bash

find ../applications -maxdepth 1 -mindepth 1 -exec ./docker_build.sh {} \;
