#!/bin/bash -e

# for use with helm post-renderer, see https://github.com/thomastaylor312/advanced-helm-demos/blob/master/post-render/kustomize/kustomize
# requires kustomize v3.5 or later

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE:-$_}))

set -e

cat <&0 > $SCRIPT_DIR/all.yaml

kustomize build $SCRIPT_DIR && rm $SCRIPT_DIR/all.yaml
