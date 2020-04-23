# Helm Charts

This directory contains [helm charts](https://helm.sh/). Most are Helm 2 compatible, 
but the more complicated charts (`ds-jupyterlab` in particular) include deployment scripts requiring Helm 3. 

## Chart Customizations

All charts contain a `scripts` subdirectory for last-mile configuration and deployment. Generally these allow site-general config to be
stored in `values.yaml`, and last-mile configuration in a VARS.txt file, e.g.

```

```

Some of the charts here are created from scratch (`nfs-drive` and `eksctl-autoscaler`, the latter of which is built from AWS docs), 
some are essentially forks of upstream charts with the addition
