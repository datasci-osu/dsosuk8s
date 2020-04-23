# Helm Charts

This directory contains [helm charts](https://helm.sh/). Most are Helm 2 compatible, 
but the more complicated charts (`ds-jupyterlab` in particular) include deployment scripts requiring Helm 3. 

## Chart Customizations

### Deployment scripts

All charts contain a `scripts` subdirectory for last-mile configuration and deployment. Generally these allow site-general config to be
stored in `values.yaml`, and last-mile configuration in a text file (see examples in `deployments`). 

```
APPNAME=example-hub
KUBE_CONTEXT=cluster-example           
CLUSTER_HOSTNAME=cluster-example.datasci.oregonstate.edu
SECURITY_SALT=any-alphanumeric-plus_and-

### ...
```

These are sourced by `deploy_from_settings.sh` and `teardown_from_settings.sh` scripts in each `scripts` directory, to be run as `<chart>/scripts/deploy_from_settings.sh VARS.txt`; because these are sourced from bash scripts, they are programmable and dynamic:

```
APPNAME=example-hub
KUBE_CONTEXT=cluster-example           
CLUSTER_HOSTNAME=cluster-example.datasci.oregonstate.edu
SECURITY_SALT=$(openssl rand -hex 32)

### ...
```

Because charts are modular (the `ds-jupyterlab` deploy requires a specified `nfs-server` deployment to base its home directory on), a single vars file can be used to simply describe multi-chart deployments and teardowns, and the scriptability enables safety checks etc. during these processes. Scripts like `hub_deploy.sh` in the main `scripts` folder take such a vars file and wrap individual chart deployments.

*Note: There may be more kube-native ways to accomplish last-mile configuration and complex deployments. Kustomize is used internally by some charts, and other similar tools may be of use: https://github.com/ramitsurana/awesome-kubernetes#configuration, https://github.com/ramitsurana/awesome-kubernetes#application-deployment-orchestration. Initialization containers may also be useful.*

### Chart Provenance

Some of the charts here are created from scratch (`nfs-drive` and `eksctl-autoscaler`, the latter of which is built from AWS docs), 
some are essentially forks of upstream charts with the addition of the `scripts` folder (`grafana`, `prometheus`, `velero`) and customized `values.yaml`, and some are "umbrella" charts with upstream charts forked as a dependency (`ds-jupyterlab`, `nginx-ingress`). 

In the latter cases, we've avoided modifying templates to make future updates easier. This is difficult for the `ds-jupyterlab` chart which deploys the main JupyterLab application - the base `jupyterhub` chart requires quite a lot of site-specific configuration (set in `values.yaml`), last-mile configuration (processed by `deploy_from_settings.sh`), also some non-templated last-mile configuration (which can't be overridden in a helm-friendly way yet) which are handled with `kustomize` and the Helm 3 `--post-renderer` option. 

### Chart Versioning

This repo's `docs` folder is not documentation - it's a [Helm chart repository](https://medium.com/@mattiaperi/create-a-public-helm-chart-repository-with-github-pages-49b180dbb417) hosted by GitHub pages (using the `docs` folder option for GitHub pages rather than the `gh-pages` branch).

The `helm_repo_build.sh` script in the main `scripts` folder builds chart tarballs from sources and updates the main repo index. Chart version information is augmented with changelog info via semantic versioning (non-standard for helm charts, but it seemed logical):

```
# in Chart.yaml
# ...

changeLog:
  v1.3.2:
    minor:
    - fixing shiny server
  v1.3.1:
    patch:
    - refactored start.sh and volume files
    minor: 
    - user admin can be switched on/off (requires user-server restart)
  v1.2.0:
    minor: 
    - Update deploy scripts to use more defaults.
  v1.1.2:
    patch: 
    - slight cleanup values.yaml and deploy scripts
  v1.1.1: 
    major:
    - First properly versioned chart (yay)
    minor:
    - Recently working RAM meter in user UI
    - Added ability for admins to install JLab extensions (needs ~2G RAM to build)
```

`hub_deploy.sh` and `hub_teardown.sh` (in the main `scripts` folder) have been configured to read the chart location and deploy that specific chart version (by downloading an unpacking it) and running the contained `scripts/deploy_from_settings.sh`, allowing for fully-versioned deployments while still doing easy last-mile customization etc. 

This has not yet been implemented for `bootstrap_cluster_deploy.sh` and `bootstrap_cluster_teardown.sh`, which install/remove the grafana, prometheus, velero, eksctl-autoscaler, and nginx charts to bootstrap a cluster making it ready for hub deployments. 
