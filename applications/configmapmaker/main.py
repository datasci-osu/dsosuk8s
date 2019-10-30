#!/usr/bin/python
# -*- coding: UTF-8 -*-

import sys
import os
import uuid
from kubernetes import client
from kubernetes.client.rest import ApiException

#
app_name = os.environ['APP_NAME']
pod_namespace = os.environ['POD_NAMESPACE']
pod_ip = os.environ['POD_IP']
with open("/var/run/secrets/kubernetes.io/serviceaccount/namespace") as f:
    namespace = "@".join(f.readlines())

def short_uuid():
    id = str(uuid.uuid4())
    return id[-12:]

def main():
    SERVICE_TOKEN_FILENAME = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    SERVICE_CERT_FILENAME = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    KUBERNETES_HOST = "https://%s:%s" % (os.getenv("KUBERNETES_SERVICE_HOST"), os.getenv("KUBERNETES_SERVICE_PORT"))

    ## configure 
    configuration = client.Configuration()
    configuration.host = KUBERNETES_HOST
    if not os.path.isfile(SERVICE_TOKEN_FILENAME):
        raise ApiException("Service token file does not exists.")
    with open(SERVICE_TOKEN_FILENAME) as f:
        token = f.read()
        if not token:
            raise ApiException("Token file exists but empty.")
        configuration.api_key['authorization'] = "bearer " + token.strip('\n')
    if not os.path.isfile(SERVICE_CERT_FILENAME):
        raise ApiException("Service certification file does not exists.")
    with open(SERVICE_CERT_FILENAME) as f:
        if not f.read():
            raise ApiException("Cert file exists but empty.")
        configuration.ssl_ca_cert = SERVICE_CERT_FILENAME
    client.Configuration.set_default(configuration)

    name = 'info-' + app_name
    configmap = {"kind": "ConfigMap", 
                 "apiVersion": "v1",
                 "metadata": {
                     "name": name
                   },
                 "data": {"app_name": app_name,
                          "pod_namespace": pod_namespace,
                          "pod_ip": pod_ip}}

    try:
        ret = client.CoreV1Api().create_namespaced_config_map(namespace = pod_namespace, body = configmap)
        #list_namespaced_config_map(namespace=os.getenv("CHART_NAMESPACE"), field_selector=("metadata.name=%s" % os.getenv("CHART_FULLNAME")), watch=False)
    except ApiException as e:
        print("Exception when calling CoreV1Api->list_namespaced_config_map: %s\n" % e)

if __name__ == '__main__':
    main()
