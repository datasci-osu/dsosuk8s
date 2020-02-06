#!/bin/bash
helm upgrade homedrive-ex2 ./../../charts/drive/latest --namespace ex2 --atomic --cleanup-on-fail --install --values 1-drive.yaml
