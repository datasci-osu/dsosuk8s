# For System Administrators

DS@OSU was originally built to run on AWS as a design requirement--AWS' lagging kubernetes support 
thus dictated several design and at this time DS@OSU only targets AWS (though with some modifications
*should* be able to run on Azure or GCP, though these infrastructures provide features such as RWX volumes
that would be best used with a significant refactor).

The shared-storage model provides the primary features of DS@OSU, but also the complexity of demployment
and management. Because AWS kubernetes does not support RWX volumns (volumes writable by many pods), shared
storage is implemented with in-cluster NFS deployed alongside each hub. For data protection and flexibility
these are deployed independently (with helm), though custom deployment scripts and helm charts automate the 
creation and removal of these hub+storage pairs. 

## Prerequisites

Although deployment scripts automate much of the management work, system administrators should be at least
minimally familiar with AWS, docker, and kubernetes--especially helm charts, namespaces, and pod management
(inspecting logs, killing pods, evaluating resource usage). 

* **eksctl and AWS**

   Clusters are deployed and configured with [`eksctl`](https://eksctl.io/) using cluster definitions found in `cluster/eksctl`--you will
   also need AWS command-line access configured for `eksctl`. 

* **kubectl**

   The [`kubectl`](https://kubernetes.io/docs/tasks/tools/) utility is required for kubernetes cluster management. Also recommended are `krew`, a plugin manager 
   for `kubectl`, and the `krew` plugin `ns` for fast namespace switching. Don't forget to alias `k=kubectl` in your
   `.bashrc` or similar. 

* **helm3**

   The package manager for kubernetes. Make sure to get [version 3](https://helm.sh/docs/intro/install/). 

* **helm-kush**

   This is a custom plugin helm (short for "helm-kustomize-sh") to support more flexible templating and 
   scripting in helm charts reducing the need to micromanage configuration. Install with 
   `helm plugin install https://github.com/oneilsh/helm-kush`

* **velero**

   If you want to use the [velero](https://velero.io/) tool for automated volume-snapshot-based backups. 

* CNAME and SSL Certificates

   You will need a DNS CNAME you can point to the public IP of the cluster, and corresponding SSL certificates
   (we use wildcard certificates, but this shouldn't be required, even for a cluster hosting multiple JupyterHub instances).

## Cluster Deployment

### 00 Cluster creation with `eksctl`

First, start by checking out the master branch of this repo:

```bash
git clone https://github.com/oneilsh/dsosuk8s
```

Next, you'll need to create a cluster--the example definition in `cluster/eksctl/example-cluster.yaml` contains
an example for use with JupyterHub deployments, including different nodepools for cluster-scoped resources described below (ingress, autoscaler, etc.),
NFS storage pods and JupyterHub "hub" pods (which run for long periods of time and thus prevent efficient down-scaling), and several types for user pods (which run for
shorter periods of time allowing more down-scaling opportunities). User-facing nodepool sizes are `t3a.large`, `t3a.2xlarge`, and `g4dn.xlarge` (for GPU-compute; note 
that this nodepool references a specific AMI image for kubernetes 1.16 compatibility). 

Experience suggests it is not a good idea to use small instance types for user-facing pods; a 1 CPU, 4 Gb RAM node for example can only host 4 students if each is gauranteed 1G of RAM; these small numbers result in too-frequent autoscaling causing service issues and frequent autoscaling wait times. The default hub deployment
described later gaurantees students 0.1 CPU and 0.5 Gb RAM and limits users to 1.0 Gb RAM; `t3a.large` nodes thus support between 8 and 16 users. Very active clusters 
may want to use `t3a.2xlarge` and larger sizes only. 

You may wish to edit the `example-cluster.yaml` definition to change the cluster name and other information - see comments in the file for more details. Assuming the command-line `aws` and `eksctl` utilities are installed and configured to create AWS resources, the cluster can be created with

```bash
eksctl create cluster -f dsosuk8s/cluster/eksctl/example-cluster.yaml
```

AWS EKS clusters take a while to create, so be patient. After installation you may want to see the new cluster "context" with `kubectl config get-contexts` 
and rename the context to something shorter with `kubectl config rename-context`, especially if you are managing multiple clusters. 

By the way, given how easy it is to create and destroy entire clusters, it is wise to have at least a "production" cluster and a "test" cluster. You may even 
decide to create new clusters rather than upgrade existing ones for upgrades to critical cluster components, migrating users or letting old clusters 'age out'.

### 01 Cluster Ingress

The `example-deployment` folder in this repo contains a number of yaml files to configure required tooling on the cluster. The first of
these is `01-ingress.yaml`, which contains the following fields that need to be set:


`kubeContext`: the name of the kubernetes context (cluster) as reported by `kubectl config get-contexts`. Example: `"prod-cluster"`

`masterHost`: a CNAME under your control. Example: `"prod-cluster.datasci.institution.edu"`

`*.cert` and `*.key`: replace these 4 entries with paths to certificate files for the CNAME on your local machine

Although two of the paths live under `wildcardTLS`, this section should be optional, as all access will be under
the hostname provided by `masterHost` without other subdomains (utilizing the nginx-ingress' "master/minion" features).

Deploy the file against the ingress chart using the `helm-kush` plugin as follows:

```bash
helm kush upgrade master-ingress dsosuk8s/charts/nginx-ingress --install --kush-interpolate --values 01-ingress.yaml
```

To check the deployment status, run `helm list -n cluster-tools` or `kubectl get all -n cluster-tools`. 

Finally, to complete the ingress installation, point your CNAME at the external IP returned by

```bash
kubectl get service -n cluster-tools master-ingress-nginx-ingress
```

### 02 Cluster Autoscaler

Next, we need to deploy the autoscaler responsible for scaling AWS nodepools up and down depending on usage; `02-autoscaler.yaml` handles
this and needs the following configuration:

`kubeContext`: the name of the kubernetes context (cluster) as reported by `kubectl config get-contexts`. Example: `"prod-cluster"`

`clusterName`: the name of the cluster as defined in the `eksctl` configuration file. Example: `"prod-cluster"`

If you customized the user nodegroups in the `eksctl` configuration file, you should also customize the `properties` section
of the `02-autoscaler.yaml` file, with more expensive machines having smaller priority values. This causes the autoscaler
to select the cheapest sufficient nodepool to scale up when a scaleup is needed. 

(Note that by default, kubernetes clusters
distribute lads in a most-available-resources fashion, resulting in behavior similar to round-robin scheduling. JupyterHub uses
a custom scheduler instead to pack nodes tightly (least-available resources) allowing nodes more chances to be empty as users come and go, thereby allowing
the autoscaler to scale back down, since only empty nodes will be removed (juptyerhub users' resources are marked as un-bumpable)).

Deploy the autoscaler with:

```bash
helm kush upgrade master-ingress dsosuk8s/charts/eksctl-autoscaler --install --kush-interpolate --values 02-autoscaler.yaml
```

*A special note about the AWS autoscaler*: due to the way previous versions of the AWS autoscaler worked, it may be unaware of resources provided by nodepools
until it sees at least one node from that nodepool, causing known issues with scaling from 0. (Though these issues may be fixed with [`recent improvements`](https://eksctl.io/usage/autoscaling/#scaling-up-from-0) to
AWS and eksctl, your milage may vary). It is for this reason that the example `eksctl` cluster definition files sets the desired size for new nodepools to 1: the
cluster is created with a single node in every pool, and when the autoscaler comes online it uses these to determine nodepool resources. Then, it should
realize that some of these are running no workloads and scale them back down to 0. If for some reason you find that the nodepool is not scaling up from 0
as expected, try setting the minimum size to 1 in the AWS GUI console (in the EC2 panel, under autoscaling groups), or with `eksctl scale` which should
re-trigger the autoscaler to recognize the nodepool. 

Be aware that it is also possible to add new nodepools to an existing cluster with `eksctl`, for example provide a new instance size for users to take advantage of. 

### 03 Cluster Registry

Docker images used are hosted on DockerHub; these include JupyterHub defaults and custom images for the hub (https://hub.docker.com/r/oneilsh/jupyterlab-k8s-hub) and user-server compontents (https://hub.docker.com/r/oneilsh/jupyterlab-ubuntu-nvidia-scipy-rjulia and other flavors). While DockerHub is convenient, it presents two
challenges:

1. DockerHub recently instituted a maximum pulls-per-day policy for images
2. the user images can be quite large--up to 12 gigs fora  full software stack and common libraries

Every time a new node is spawned by the autoscaler, these images need to be loaded. The size of the images slows down scaleup and dockerhub limits may cause issues. 

To mitigate this `03-registry.yaml` configures a local docker image repository in the cluster, configured as a "[pull-through cache](https://docs.docker.com/registry/recipes/mirror/)" of dockerhub. Hubs deployments are configured to use this local registry by default. 

The only configuration needed is: 

`kubeContext`: the name of the kubernetes context (cluster) as reported by `kubectl config get-contexts`. Example: `"prod-cluster"`

And the deployment works similarly to others:


```bash
helm kush upgrade registry dsosuk8s/charts/docker-registry --install --kush-interpolate --values 03-registry.yaml
```

One other caveat about DockerHub: they've also announced a new policy (coming mid-2021) of *removing* "stale" images
that are not pulled or pushed for some amount of time. You may thus want to `docker pull` them periodically manually (or via CRON job),
especially since local caching of images in the registry means many fewer pulls from dockerhub. 

We haven't investigated this yet, but [this post](https://poweruser.blog/avoiding-the-docker-hub-retention-limit-e18cdcacdfde) may prove useful.


### 04 Cluster GPU Driver

If you plan to support GPU-compute, you'll need to also install the NVIDIA GPU-driver component from `04-gpudriver.yaml`. Again the only
config needed is to specify the cluster target: 

`kubeContext`: the name of the kubernetes context (cluster) as reported by `kubectl config get-contexts`. Example: `"prod-cluster"`

and to deploy:


```bash
helm kush upgrade registry dsosuk8s/charts/nvidia-device-plugin --install --kush-interpolate --values 04-gpudriver.yaml
```

The `image` line in the config file configures the installation to also make use of the local image registry/pull-through cache (since
these images are similarly installed on every node). 

Note GPU utilities (e.g. tensorflow) are not present in the default user image and should be configured with a custom compute profile (see below).

### 05 Cluster Monitoring: Prometheus

Prometheus is one of two components (Grafana being the other) for monitoring cluster resources and usage. Prometheus provides data export from
nodes, while Grafana is a visualization tool specializing in large timescale data. `05-prometheus.yaml` needs only the same `kubeContext` config as
above:

`kubeContext`: the name of the kubernetes context (cluster) as reported by `kubectl config get-contexts`. Example: `"prod-cluster"`

and is deployed with 

```bash
helm kush upgrade registry dsosuk8s/charts/prometheus --install --kush-interpolate --values 05-prometheus.yaml
```

In our experience prometheus and grafana can occasionally crash if one attempts to visualize too much data simultaneously (resource needs
are defined in the chart directory and you may consider increasing them, subject to the resources defined for the clustertools nodepool). It's thus 
handy to know that this component (and most components, in fact) can be deleted with

```bash
helm delete prometheus -n cluster-tools
```

and then reinstalled with the `helm kush upgrade` command above. You may want to try reinstalling Grafana (below) only first, but you may need to remove both prometheus and grafana before re-installing both, should you need to. 

### 06 Cluster Monitoring: Grafana

Grafana is the visualization component of the prometheus/grafana pair, and `06-grafana.yaml` has several fields in need of setting:

`kubeContext`: the name of the kubernetes context (cluster) as reported by `kubectl config get-contexts`. Example: `"prod-cluster"`

`clusterHostname`: the CNAME of the cluster as used by the ingress; Example: `"prod-cluster.datasci.institution.edu"`

`adminPassword`: the initial password for the admin user. Example: `"heythattickles"`

After installing with 

```bash
helm kush upgrade grafana dsosuk8s/charts/grafana --install --kush-interpolate --values 06-grafana.yaml
```

you should be able to (eventually, after the install completes) navigate to `https://<clusterHostname>/grafana` and login 
with username `admin`, password `<adminPassword>`. It is wise to change the admin password immediately. 

Grafana is configured with "dashboard" files (in JSON format) for specific visualization dashboards--this repo includes
a dashboards to monitor JupyterHub activity in `cluster/grafana_prometheus/jhub_cluster_metrics.json` and a dashboard for
more general cluster metrics in `cluster/grafana_prometheus/cluster_dashboard.json`. To add one of these dashboards in Grafana, 
use the + icon in the left navigation menu and select "Import", then just paste in the JSON file contents. 

These dashboards are far from perfect; you can explore other kubernetes Grafana dahsboards at [grafana.com](https://grafana.com)
and another JupyterHub-specific dashboard for the popular [mybinder.org](https://mybinder.org) service at [grafana.mybinder.org](https://grafana.mybinder.org). The

As with prometheus, if Grafana crashes it can be removed with 

```bash
helm delete grafana -n cluster-tools
```

before reinstalling with the `helm kush upgrade` command. 

### 07 Cluster Backups: velero

Velero is a tool for routine backups of resources and data in kubernetes clusters. Backups and restores via entire volume snapshots, and are
not easy to restore, so this is not recommended for "ooops, I need a file undeleted" except for extreme cases. It can however provide some
extra measure of safety should the absolute worst happen.

To use velero, you must configure an AWS S3 buicket and IAM permissions to access it: see [the AWS plugin on GitHub](https://github.com/vmware-tanzu/velero-plugin-for-aws) for details. At the end, you should have a defined BUCKET (string), REGION (string), and credentials (file). Configure
the following in the `07-velero.yaml` file:

`kubeContext`: the name of the kubernetes context (cluster) as reported by `kubectl config get-contexts`. Example: `"prod-cluster"`

`veleroS3Bucket`: name of the configured bucket. Example: `"prod-velero-backups"`

`veleroBackupRegion`: name of the configured region. Example: `"us-west-2"`

`eksClusterName`: name of the cluster as defined in the EKS cluster definiton file. Example: `"prod-cluster"`

`veleroCredentialsFile`: path to the credentials file. Example: `"/path/to/prod-velero-backups.creds"`

As usual, the install is

```bash
helm kush upgrade velero dsosuk8s/charts/velero --install --kush-interpolate --values 07-velero.yaml
```

We'll leave the creation of backup schedules and restore procedures to the offical documentation at [velero.io](https://velero.io/docs/).

Notes: As well discuss below, user data volumes are removed from kubernetes when a hub is deleted, *but*, the volume itself in AWS is not. It is simply 
detached from the node, but is still available in the AWS EC2 GUI console, and these detached volumes must be removed manually periodically (detached
volumes still cost money!). This provides a safety mechanism for post-hub-deletion recovery independent of velero. Unfortunately, the names given to volumes
are not human readable, making it difficult to associate a volume with a hub (especially after the hub has been deleted!)

Additionally, new hubs are generally created with *new* storage, and there is currently no automated feature for directing a new hub to use previous existing
storage (either from backup or undeleted detached volumes). When the need has arizen to migrate data from one hub to another, we've generally done so by manually
zipping the shared drive contents and staging them to a 3rd server before pulling into the target Hub's storage. If the jupyterhub is not function, it is possible
to log directly into the running NFS server with `kubectl exec`; see below for more details on managing user data. 


### 08 Cluster Placeholders

In the standard configuration, JuptyerHub suppots the use of "placeholders" -- these fake users are "bumpable" from nodes 
by real users (real users are not bumpable), and help ensure that some amount of resources are ready and available for users on login. 
For example, consider a node that can support 8 users, and is currently being utilized by 6. If 3 new users login in rapid succession, 2 will be able to login
immediately, while the third will have to wait until a new node autoscales up which can take several minutes. (During this time their login waits at a progress 
bar and shows a number of scary-looking warnings and errors that aren't actually problems.) However, if say 8 placeholders are used, then there will be 2 nodes
prior to the new user logins: one (node A) hosting the 6 real users and 2 placeholders, and the other (node B) hosting the other 6 placeholders. When the 3 new
users login, two can be placed on node A (bumping 2 placeholders to node B, making it full), and the other two will land on node B, bumping two placeholders.
These bumped placeholders will then need to wait on a new node to autoscale up. 

Placeholders thus "keep seats warm" for students. They are not a perfect solution: if 30 users attempt to login in rapid succession not enough warm seats may be available and some users will need to wait for autoscaling regardless. (This happens commonly at the start of lab-based classes, see management sections below for 
mitigation strategies). 

However, this is one pernicious issue with placeholders that can lead to failures to start when a single cluster hosts multiple instancs of JupyterHub,
documented [here](https://www.mail-archive.com/jupyter@googlegroups.com/msg05004.html). The recommended workaround, which we implement via `08-placeholders.yaml`, 
is to create a single JupyterHub to house all the placeholders, and then to configure all other hubs to use the placeholder hub's scheduler component. `08-placeholders.yaml` thus deploys a hub for the sole purpose of housing placeholders for the entire cluster. 

The relavent configuration fields are: 

`kubeContext`: the name of the kubernetes context (cluster) as reported by `kubectl config get-contexts`. Example: `"prod-cluster"`

`clusterHostname`: the CNAME of the cluster as used by the ingress; Example: `"prod-cluster.datasci.institution.edu"`

`securitySalt`: set this to some random (non-whitespace) characters; even though it won't be possible to login to this hub, this field ensures the encrypted communications between the hub and placeholders remains secure. Example: `"kjabsdflhgsldfbaljsdfblasdhfkbf"`

`jupyterhub.scheduling.userPlaceholder.replicas`: number of placeholders to use. Example: 20

`jupyterhub.singleuser.memory.{guarantee,limit}`: the guarantee value is how much RAM each placeholder will consume, and the limit must be higher. Example: `"0.5G"` and `"1.0G"`

`jupyterhub.singleuser.cpu.{guarantee,limit}`: the guarantee value is how much CPU each placeholder will consume, and the limit must be higher. Example: `0.1` and `1.0`

Deploy the placeholder hub with: 

```bash
helm kush upgrade placeholders dsosuk8s/charts/ds-jupyterlab --install --kush-interpolate --timeout 10m0s --values 08-placeholders.yaml
```

The above sets the timeout to 10 minutes, as the first install of a JupyterHub on a cluster typically takes a while as various docker images are pulled and components
communicate. Should the process fail due to timeout, try again. 

You may want to change the number and size of placeholders as your cluster usage grows. Fortunately, this is easy to do: just edit the configuration file
and redeploy with the above deployment command, and kubernetes will align the actual configuration with the requested on. You can see the running placeholders
(and other placeholder hub components) with `kubectl get all -n placeholders`.

Unfortunately, at this time due to the nature of the issue and the workaround it is not possible to deploy placeholders of varying sizes, making it difficult
to deploy placeholders that keep nodepools of different sizes warm. In practice we use a standard 0.5G RAM and 0.1 CPU placeholder size for the most common
case of keeping small-compute seats warm, and no placeholders large enough to ensure warm seats for larger node types and compute profiles, resulting in autoscaling waits for those.

Should you need to remove the placeholder hub, a more complex removal command is needed to remove all of the hub's components (including the shared storage component, even though it's not a requirement for the placeholder hub and unused it is still created). 

To delete:

```bash
helm kush run uninstall dsosuk8s/charts/ds-jupyterlab placeholders
```


## Hub Deployment and Management

```
Hub launch URL: https://hub-green.datasci.oregonstate.edu/example-simple/hub/lti/launch
Consumer Key: 9cc6ebca80d7aa322cfbafb72565b79f35ee374c22d98f5fa4160fa28a98f330
Shared Secret: dbc3eb6f43a6ca0256c0a1a60c8fa11a336308cefc770d1afffb635e59e41974
```

