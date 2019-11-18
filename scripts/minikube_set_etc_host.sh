#!/usr/bin/env bash

sudo sed -i -e 's/.*minikube.*/'$(minikube ip)$'\tminikube.local/' /etc/hosts

