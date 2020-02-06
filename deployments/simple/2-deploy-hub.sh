#!/bin/bash
helm upgrade hub-ex2 ./../../charts/ds-jupyterlab/latest --namespace ex2 --atomic --cleanup-on-fail --install --values 2-hub.yaml
