#!/bin/bash

helm upgrade homedrive-example ../../charts/drive/latest/ --namespace example-namespace --atomic --cleanup-on-fail --force --install --values drive.yaml
