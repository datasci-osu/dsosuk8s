#!/bin/bash

helm upgrade lab-example ../../charts/ds-jupyterlab/latest --namespace example-namespace --atomic --cleanup-on-fail --force --install --values ds-jupyterlab.yaml
