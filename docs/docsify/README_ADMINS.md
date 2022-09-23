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
git clone https://github.com/datasci-osu/dsosuk8s
```

Next, you'll need to create a cluster--the example definition in `example-deployment/cluster/example-cluster.yaml` contains
an example for use with JupyterHub deployments, including different nodepools for cluster-scoped resources described below (ingress, autoscaler, etc.),
NFS storage pods and JupyterHub "hub" pods (which run for long periods of time and thus prevent efficient down-scaling), and several types for user pods (which run for
shorter periods of time allowing more down-scaling opportunities). User-facing nodepool sizes are `t3a.large`, `t3a.2xlarge`, and `g4dn.xlarge` (for GPU-compute). 

Experience suggests it is not a good idea to use small instance types for user-facing pods; a 1 CPU, 4 Gb RAM node for example can only host 4 students if each is gauranteed 1G of RAM; these small numbers result in too-frequent autoscaling causing service issues and frequent autoscaling wait times. The default hub deployment
described later gaurantees students 0.1 CPU and 0.5 Gb RAM and limits users to 1.0 Gb RAM; `t3a.large` nodes thus support between 8 and 16 users. Very active clusters 
may want to use `t3a.2xlarge` and larger sizes only. 

You may wish to edit the `example-cluster.yaml` definition to change the cluster name and other information - see comments in the file for more details. Assuming the command-line `aws` and `eksctl` utilities are installed and configured to create AWS resources, the cluster can be created with

```bash
eksctl create cluster -f dsosuk8s/example-deployment/cluster/example-cluster.yaml
```

AWS EKS clusters take a while to create, so be patient. After installation you may want to see the new cluster "context" with `kubectl config get-contexts` 
and rename the context to something shorter with `kubectl config rename-context`, especially if you are managing multiple clusters. 

By the way, given how easy it is to create and destroy entire clusters, it is wise to have at least a "production" cluster and a "test" cluster. You may even 
decide to create new clusters rather than upgrade existing ones for upgrades to critical cluster components, migrating users until the old one can be de-commissioned.

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
AWS and eksctl, [your milage may vary](https://github.com/kubernetes/autoscaler/issues/3780)). It is for this reason that the example `eksctl` cluster definition files sets the desired size for new nodepools to 1: the
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

With the cluster configured and ready, we can move onto deploying hubs. Hubs and shared storage components are managed as helm chart deployments, 
with each hub/storage pair living in a kubernetes namespace of the same name. Consider a hub for the hypothetical class MB652; a deployment may
consist of a kubernetes namespace `mb652hub`, containing a `mb652hub` helm deployment for the hub (consisting of the standard components defined by 
[Z2JH](https://zero-to-jupyterhub.readthedocs.io/en/stable/)) and a `mb652hubhomedrive` helm deployment (consisting of an a kubernetes persistent volume 
bound to an NFS server, which is then mounted by the hub components). (This split allows for better re-use of Z2JH stack and the planned for (but not yet
implemented) ability to re-use or share storage across hubs, or connect multiple storage volumes to a single hub.)

The helm-kush enhanced helm chart in `charts/ds-jupyterlab` enables minimal configuration work and coordianated commissioning and de-commissioning of the 
component parts. 

### Basic Hub Install (Canvas)

The example deployment file `example-deployment/example-simple.yaml` describes required configuration for a basic Canvas-connecting hub, which is the default
authentication option.

```yaml
kubeContext: hub-green
clusterHostname: hub-green.datasci.oregonstate.edu


securitySalt: supersecret
createHomeDrive:
  size: 50Gi
  chart: https://datasci-osu.github.io/dsosuk8s/nfs-drive-1.1.0.tgz


jupyterhub:
  singleuser:
    memory: {guarantee: 0.5G, limit: 1.0G}
    cpu:    {guarantee: 0.1,  limit: 1.0}
```

The configuration fields `kubeContext` and `clusterHostname` are the same as for cluster components: these should be the target kubernetes clsuter context name
(as reported by `kubectl config get-contexts`) and the cluster hostname (CNAME used during ingress setup). The `securitySalt` field should be any string
and kept secret (non-whitespace unless wrapped in quotes as allowed by YAML syntax). Default Z2JH deployments utilize a security key which is required to be a
32-character hex string; here we've customized the deployment to compute this based on a hash of the security salt and other hub metadata. 

The `createHomedrive` section defines the shared storage space available to users (and points to the helm chart version used for the NFS server). *Note that it is not
possible at this time to resize storage for a hub.* (This is possible in theory, but not implemented.) Storage utilizes standard AWS EBS volumes at 10 cents per gigabyte
per month as of this writing. 

Lastly, the `jupyterhub.singleuser` section defines the resources made available to logged in users: guarantees reserve that amount for the user regardless of usage,
and limits allow users to utilize more resources if they are available. 

Note that CPU is highly fungible and bursty in nature--most of the time most users require only a tiny fraction of CPU, but on occasion burst to needing several cores. 
Given that kubernetes can fairly redistribute CPU resources proportionally it makes sense to set a low gaurantee and high limit for CPU. RAM on the other hand is less
fungible: once allocated by a user it is reserved until the process releases it (frequently only on user logout). RAM resources thus should be be tailerd more closely
to user needs. Fortunately, these values can be changed at any time with minimal disruption (see Changing Configuration below).

The hub is deployed via

```bash
helm kush upgrade <hubName> ../charts/ds-jupyterlab --install --kush-interpolate --timeout 10m0s --values <hubConfig.yaml>
```

For example, `helm kush upgrade example-simple ../charts/ds-jupyterlab --install --kush-interpolate --timeout 10m0s --values example-simple.yaml`. Once the hub is deployed (which can take several minutes), the install will report 3 pieces of information necessary to connect the hub to Canvas:


```
Hub launch URL: https://hub-green.datasci.oregonstate.edu/example-simple/hub/lti/launch
Consumer Key: 9cc6ebca80d7aa322cfbafb72565b79f35ee374c22d98f5fa4160fa28a98f330
Shared Secret: dbc3eb6f43a6ca0256c0a1a60c8fa11a336308cefc770d1afffb635e59e41974
```

The hub then needs to be "connected" to the Canvas course in the following way (and this requires sufficient priveledges in the Canvas course such as Instructor or Designer). Under the course **Settings**, click the **Apps** tab, and then **View App Configurations** button. 

![](media/canvas_app_configurations.png ':size=90%')

Next, click the **+App** button near the top of the resulting page, and enter the launch URL, Consumer Key, and Shared Secret as shown below. Be sure to 
select "Public" in the privacy dropdown: this allows Canvas to share user login names with the hub. 

![](media/addapp.png ':size=60%')

The hub can then be accessed in Canvas by adding either 1) an "External Tool" module int he Modules section, or 2) an assignment with the "External Tool" submission type. In both cases, use the Find button to locate the newly installed app, or just enter the launch URL in the link section of the dialog. Be sure to check
"load This Tool In A New Tab" or it won't work. 

![](media/canvas_external_tool.png ':size=70%')

Finally, users (instructors and students) can log into the hub by opening the relavent assignment or module and click the "launch" button. The timeout for clicking the button after page load is short--if the the page is open for too long it will report an error, but refreshing the page restores the button and restarts the timer. 

#### Username configuration

Usernames in a Canvas-connected hub are parsed from information provided by the Canvas API. To complicate matters, institutions may customize this information
and how/where it is stored in the response from Canvas. As Oregon State U., usernames are provded as `<username>@oregonstate.edu` in the `custom_canvas_user_login_id` field. (Information passed form Canvas to the hub on user login is is logged in the hub container logs, these can be used to inspect the fields and formatting provided. See Viewing Logs below for information.) This is true *unless* the instructor is using "student view" in Canvas, in which case the `custom_canvas_user_login_id` field is a long random hex string. The OSU Canvas instance also supports user-managed Canvas "Studio Sites" that allow social logins, and are nice options for short workshops etc. In these cases the username is reported as their social login email in the `lis_person_contact_email_primary` field.  

These various username options need to be mapped to a username in the hub, and ideally usernames would be username-like: short, memorable, and unique. For regular class use, we can gaurantee that the `<username>` segment of `<username>@oregonstate.edu` is unique (and is in fact the users' OSU net ID) and so is a fine username. Social logins cannot use the same extraction; `joe@gmail.com` should not get access to the same account as `joe@oregonstate.edu` (or any other Joe). For these cases we use the entire social login email as the username. For usernames provided by the "student view" we truncate the long hex string IDs to just the first 6 characters, so `19ab34cfdd87168e` becomes hub username `19ab34`. 

This is accomplished via a customized version of the [ltiauthenticator](https://github.com/oneilsh/ltiauthenticator) JupyterHub plugin to map potential usernames
to hub usernames via a series of regular expressions with capture groups. Configuration can be customized via environment variables as follows:


```yaml
jupyterhub:
  singleuser:
    memory: {guarantee: 0.5G, limit: 1.0G}
    cpu:    {guarantee: 0.1,  limit: 1.0}

  hub:
    extraEnv:
      LTI_ID_KEYS: '["custom_canvas_user_login_id", "lis_person_contact_email_primary", "custom_canvas_user_login_id"]'
      LTI_ID_REGEXES: '["(^[^@]+)@[^@]+$", "(^[^@]+@[^@]+$)", "(^[0-9a-f]{6,6})[0-9a-f]*$"]'
      LTI_ADMIN_ROLES: '["Instructor", "TeachingAssistant", "ContentDeveloper"]'
```

The username-mapping process happens as follows: each field listed in `LTI_ID_KEYS` is matched in turn with the corresponding (by array index) 
regular expression in `LTI_ID_REGEXES`. If a match is found, the username is grabbed from the first capture group (in `()`), otherwise the next in line
is checked. (If none match, a default is used, the LTI user ID, which is unlikely to be anything more than a long random string.) Notice that this example, which is the
default, implements the logic described above. 

The `LTI_ADMIN_ROLES` value describes a set of Canvas-defined roles that should be given admin access in the hub. The example aboe makes Instructors, TAs, 
and "Content Developers" admins, but one could e.g. remove `"TeachingAssistant"` from the list to make them regular users in the hub. This means that a person
can be an admin in one hub, and a regular user in another, depending on their Canvas role. Roles and access can also be changed from within Canvas, and their group/admin
permissions will be updated in the hub to reflect to the change (though all files previously owned by will preserve their permissions regardless of location). 

One last thing to note: usernames are mapped to Unix UID numbers using a hash-based process for repeatability. When a user first logs in, this UID is associated with the username, but the UID->username mapping will only appear for user servers that were started *after* the mapping has been made (since the mapping is picked up on server start). The effect of this is that a user who lists files in the hub as other users are logging in for the first time will see UID values instead of usernames in the file listing, until they restart their own server to pickup the new UID->username mappings. 

### Basic Hub Deployment (Native Authenticator)

For deployments where Canvas is not preferred, DS@OSU is also configured to allow users to self-register with a desired username and password, with their access
being subject to approval by an admin user. This is supported by the [NativeAuthenticator](https://native-authenticator.readthedocs.io/en/latest/) plugin. To use this, 
just add two lines to the the configuration file as follows: 

```yaml
authType: native
adminUsers: oneils, keistc

jupyterhub:
  singleuser:
    memory: {guarantee: 0.5G, limit: 1.0G}
    cpu:    {guarantee: 0.1,  limit: 1.0}
```

where `authType: native` specifies to use the native authenticator, and `adminUsers` is a comma-separated list of initial usernames to designate as admins (admins
can promote other users to admin status later). 

Although [well-documented](https://native-authenticator.readthedocs.io/en/latest/), the workflow for Native Authenticator
is a little confusing. Users can sign up (pick a username and password) at the hub URL `https://<clusterHostname>/<hubName>/hub/signup`, which is linked from the main login page at `https://<clusterHostname>/<hubName>`, though the login and signup pages are very similar looking and may be confusing to users. Admin users can login and authorize/de-authorize users at `https://<clusterHostname>/<hubName>/hub/authorize`, after which those users will be able to login. Admin usernames specified in the hub
config above are *pre-authorized*, but the passwords for these usernames need to be set initially by using the signup form. All users can change their password after login by navigating to `https://<clusterHostname>/<hubName>/hub/change-password`.

### Uninstalling a Hub

To avoid issues with unmounting and releasing storage volumes hub components need to be de-commissioned in a specific order; the helm-kush enhanced chart handles this
via a custom `run` script. A hub installed with `helm kush upgrade <hubName> charts/ds-jupyterlab ...` can be removed with 

```bash
helm kush run uninstall charts/ds-jupyterlab <hubName>
```

Note that both install and uninstall utilize information in the chart (`charts/ds-jupyterlab`), so the same version of the chart should be used for both operations to ensure proper cleanup. 

Uninstalling a hub performs the following actions:

* Stopping any running user pods/servers
* Removing the main hub pod and other JuptyerHub components
* Removing the NFS server component and detaching the persistent volume for shared storage
* Removing the persistent volume claim and persistent volume (from the kuternetes cluster)
* Removing the kubernetes namespace (unless for some reason any resources still exist, in which case a warning is reported)

### Compute Profiles and Resource Allocation

The `simple-example` hub above defines simply the gauranteed and maximum allowed RAM and CPU, and user servers (the term used by JupyterHub for docker containers
running user processes) are defined by a "standard" docker image containing Python, R, Julia, and a variety of common libraries and tools. The

There may be cases, however, where a user needs to use more resources for a particular session, or a need may arise for different software stacks. Such "profiles"
are supported by JupyterHub natively, but we additionally add features via a [custom JupyterHub plugin](https://github.com/oneilsh/jh-profile-quota) for token-bucket
based quotas--these quotas limit the total time a user may use a profile, which is useful for management of expensive resources like GPUs. 

To use profiles and quotas, include a `profileList` section in the hub configuration. The `example-deployment/example-profiles.yaml` file provides an example:

```yaml
jupyterhub:
  singleuser:
    memory: {guarantee: 0.5G, limit: 1.0G}
    cpu:    {guarantee: 0.1,  limit: 1.0}
    
    profileList:
    - display_name: "Standard"
      slug: "standard"
      default: True
      description: "Standard server type suitable for programming and most analyses: 0.1 CPU gauranteed (1.0 maximum where available) and 0.5G RAM gauranteed (1G max where available)."
    - display_name: "Large"
      description: "For slightly larger computation needs: 0.25 CPU gauranteed (2.0 maximum where available) and 2G RAM gauranteed (4G max where available). <br /><br />Please note that servers with this profile may take longer than usual to start."
      slug: "large"
      kubespawner_override: {mem_guarantee: 1.9G, mem_limit: 4.0G, cpu_gaurantee: 0.25, cpu_limit: 2.0}
      quota:
        minBalanceToSpawn: 0.5
        admins: {initialBalance: 4, newTokensPerDay: 2, maxBalance: 8}
        users:  {initialBalance: 4,  newTokensPerDay: 2, maxBalance: 8}
    - display_name: "X-Large"
      description: "For heavy computation needs: 0.5 CPU gauranteed (8.0 maximum where available) and 8G RAM gauranteed (12G max where available). <br /><br />Please note that servers with this profile may take longer than usual to start."
      slug: "xlarge"
      kubespawner_override: {mem_guarantee: 7.9G, mem_limit: 12.0G, cpu_gaurantee: 0.5, cpu_limit: 8.0}
      quota:
        minBalanceToSpawn: 0.5
        admins: {initialBalance: 4, newTokensPerDay:  1, maxBalance: 6, active: false}
        users:  {initialBalance: 4,  newTokensPerDay: 1, maxBalance: 6}
    - display_name: "X-Large w/ GPU"
      description: "GPU-Based Compute: 4.0 CPU, 16G RAM, and one NVIDIA T4 GPU gauranteed. Tensorflow installed. <br /><br />Please note that servers with this profile *will* take longer than usual to start."
      slug: "gpu"
      kubespawner_override:
        mem_guarantee: 15.0G
        mem_limit: 16.0G
        cpu_gaurantee: 3.5
        cpu_limit: 4.0
        extra_resource_limits: {"nvidia.com/gpu": "1"}
        image: "localhost:30050/oneilsh/jupyterlab-ubuntu-nvidia-scipy-rjulia-gpu:v1.1.0"
      quota:
        minBalanceToSpawn: 1
        admins: {initialBalance: 4, newTokensPerDay:  1, maxBalance: 4}
        users:  {initialBalance: 4, newTokensPerDay:  1, maxBalance: 4, disabled: true}
```

This `profileList` defines 4 profiles: the "Standard" profiled defined by the main `singleuser` configuration (with no overrides, but an added display name and description), a "Large" profile, "X-Large", and finally "X-Large w/ GPU". Note that in this section only the `quota` subsections are provided by our custom module, JupyterHub provides profiles and overrides out of the box, including the options given to `kubespawner_override` which are documented [here](https://zero-to-jupyterhub.readthedocs.io/en/stable/jupyterhub/customizing/user-environment.html?highlight=kubespawner_override#using-multiple-profiles-to-let-users-select-their-environment) and [here](https://jupyterhub-kubespawner.readthedocs.io/en/latest/spawner.html). These profile options are as described in those documentation, including `display_name`, `description`, `default`, `kubespawner_override`, and `slug`, which is a machine-readable label for the profile. 

Quota configuration relies on the concept of "tokens", where 1 token equates to 1 hour of profile use, and token balances are tracked per-user, per-profile. Many settings are set indepenedently for admins and regular users, for example to allow admins (like instructors and TAs) more resources for course development. These settings are fairly self-explanatory: `initialBalance` defines the number of initial tokens, `newTokensPerDay` defines how many tokens are added to each users' balance per day (in ten minute increments by default), and `maxBalance` defines an upper limit on how many tokens a user may bank. 

The `minBalanceToSpawn` option is set profile-wide rather than for admins and users separately, and a users' token balance must be at least this much to start a server with the profile. During use, we do *not* stop user servers if they run out of tokens (usage is also accounted by checking for activity every 10 minutes). Rather than interrupting work unexpectedly, we allow token balances to go negative. This means however that the user won't be able to use the profile again after their server stops via normal means (see the next two sections for details on "normal" server stops) until they have accumulated enough token to bring their balance back above the `minBalanceToSpawn` value. Although defaults for these various options are [defined](https://github.com/oneilsh/jh-profile-quota), you should specify them explicitly for clarity. 

Two other options are available as shown in the X-Large and GPU profiles above: `active` which can be set to `false` to disable quota checking and accounting, and `disabled` which can be set to `true` to disable a profile for usage. 

Lastly, notice that the "X-Large w/ GPU" profile specifies a custom image, which is larger than the default image having a tensorflow-based software stack installed. We prefix the image name with `localhost:30050/` to indicate that images should refer to pull-through docker registry cache for efficiency. (As of this writing the only images you're likely to want to use are the default and this GPU-based image.)

Quota information is compiled in the UI where users can select their profile on server start; note that HTML is allowed in the profile description fields and we've 
included warnings about startup times for these large profiles since they are much more likely to require a cluster autoscale to start. 

![](media/dshub_profiles.png ':size=45%')
![](media/dshub_profiles_popup.png ':size=45%')

It is useful to consider profile resources in light of the cluster nodepool resources and usage patterns. The `t3a.large` nodepool defined in the example cluster
config has 16G RAM while the `t3a.2xlarge` nodes have 32G RAM. The smaller of these can thus support 4 to 8 Large profile servers (and we set the `mem_guarantee` to `1.9G` to allow for memory for the OS and other node components to support 8), or 1 or 2 X-Large profiles, with remaining space being used by some number of smaller profiles. Depending on usage patterns, this may be suboptimal: after the X-Large servers stop, the node will continue to run and support the smaller profiles until all of those stop as well (and assuming no new ones show up and land on the node), leaving the larger more-expensive node mostly empty. The example cluster configuration adds information to nodepools as *labels*, for example each nodepool contains a `nodesize` label with values of e.g. `t3a.2xlarge`. A `node_selector` field can then be added to the `kubernetes_override` section to target profiles to particular node types by label, for example `kubespawner_override: {mem_guarantee: 7.9G, mem_limit: 12.0G, cpu_gaurantee: 0.5, cpu_limit: 8.0, node_seletor: {nodesize: t3a.2xlarge}}`. Additional labels could be used to define targettable sets of nodepools. 

It is more difficult to prevent profiles from landing on a particular nodepool, though it is possible using KubeSpawner's `tolerations` option and node "taints" defined in the cluster config. [TODO: document an example!] Alternatively, in some cases it suffices to allocate resources carefully. For example, the `g4dn.xlarge` nodes have one GPU, 4 vCPUs, and 16G RAM. Since these machines are expensive, we dont' want to put any non-GPU profiles on these nodes. In fact, these should only ever support a single user at a time, and we may as well allocate to that user all available resources, so we set the gaurantees to be large enough to reserve a node to a single user (but leave a little extra for OS and other components.) [TODO: taints and tolerations are really the better solution.]

One last thing: the dynamics of the scheduler (which uses a strategy that packs nodes as tightly as possible) and the autoscaler (which uses a "cheapest first" strategy to decide which nodepool to scale up) can result in non-intuitive behavior. If for example the above were the only profiles in use on the cluster, the `t3a.2xlarge` nodepool will never be used, because there is no profile that requires this more expensive node type in liu of a cheaper one. 

### Inactivity Culling and Other Useful Config

Z2JH provides a [large number of options](https://github.com/jupyterhub/zero-to-jupyterhub-k8s/blob/main/jupyterhub/values.yaml) that can be added to hub configuration. Of particular interest (especially where profiles and resource allocation are concerned) are those that manage inactivity and max-runtime limits. Though user servers *can* be allowed to run forever, it isn't wise to allow this, as resources will stay tied up and the cluster will never be able to scale down. Turning off user servers after a period of inactivity or maximum runtime is known as *culling*. We can configure this via a `cull` section in the config, where the default values are as shown:

```yaml
jupyterhub:
  singleuser:
    memory: {guarantee: 0.5G, limit: 1.0G}
    cpu:    {guarantee: 0.1,  limit: 1.0}

  cull:
    enabled: true   # turn on culling?
    timeout: 3600   # 1 hour (in seconds)
    every: 600      # 10 minutes
    maxAge: 28800   # 8 hours
```

In these default settings, culling is enabled, and every 10 minutes the hub queries user servers for inactivity--if no activity is found for 1 hour, the server is removed (including stopping of all running processes!) "Activity" here is defined as *a browser window or tab open to the JupyterLab interface.* This means that a user logged in who leaves their browser open and logged in is active, even if they've stepped away from the keyboard for an extended period. By contrast, a user who opens RStudio (which opens in a new browser tab) and then closes the JupyterLab tab is *inactive*, even if they are actively working in RStudio. Browser extensions such as Chrome's tab-suspender that suspend non-active tabs may also result in apparent inactivity. 

To reduce the risk of apparently-always-active users, `maxAge` configures the maximum allowable runtime for a user server. Once a server is culled, the user may still start a new server to reset the timer of course, but this effectively limits the runtime of a single server and any process within it. 

By default logging out of the JupterLab interface (via File -> Logout) does *not* stop the users' server. If they were to log back in again within the timeout period their login would be nearly instantaneous as their their server already exists. This can be changed to stop a server on logout (which still requires users to explicitly log out, rather than close the browswer tab):

```yaml
jupyterhub:
  singleuser:
    memory: {guarantee: 0.5G, limit: 1.0G}
    cpu:    {guarantee: 0.1,  limit: 1.0}

  cull:
    enabled: true   # turn on culling?
    timeout: 3600   # 1 hour (in seconds)
    every: 600      # 10 minutes
    maxAge: 28800   # 8 hours

  hub:
    shutdownOnLogout: true
```

### Changing Configuration

With the exception of shared storage size and primary hub information like hub name, clusterHostname, and kubeContext, most options can be changed without user interruption by adjusting the config file and redeploying with the deployment command (`helm kush upgrade <hubName> charts/ds-jupyterlab ...`). Adjustments to user servers such as RAM and CPU allocation will not be picked up until they stop and restart. [TODO: test whether redeploying resets user quota balances. I don't think it does.]

### Viewing Logs, Exec'ing, and Killing Pods/Servers

Kuberentes supports viewing logs for, and dynamically logging into, running containers. This can be somewhat complex in general because kubernetes pods are the unit of reference, and a single pod may contain multiple containers. However, this feature is not used here and kubernetes is smart enough to work with the container directly if a pod only contains one. 

To view the running pods for a hub, use

```bash
kubectl get pods -n <hubName>
```

(Since `<hubName>` is also the namespace for a given hub.) For our simple example hub, `kubectl get pods -n simple-example` reveals 3 pods of particular interest: the
"hub" pod (`hub-787b87b8bd-fs6h8`) which handles login and "master control" of user servers, the NFS server pod (`nfs-example-simplehomedrive-dep-0`), and a single user-server pod (`jupyter-oneils`): 

```
NAME                                READY   STATUS    RESTARTS   AGE
continuous-image-puller-fxxjz       1/1     Running   0          4d
continuous-image-puller-wr5cg       1/1     Running   0          4d
hub-787b87b8bd-fs6h8                1/1     Running   0          5h32m
jupyter-oneils                      1/1     Running   0          10m
nfs-example-simplehomedrive-dep-0   1/1     Running   0          4d
proxy-f895989c6-68spb               1/1     Running   0          4d
```

Viewing logs for one of these pods is as simple as 

```bash
kubectl logs -n <hubName> <podName>
```

For example, `kubectl logs -n example-simple hub-787b87b8bd-fs6h8` shows the logs for the hub. In some cases a pod may fail and auto-restart; if this happens adding a `--previous` option will show logs for the previous failed pod for debugging. Other options of interest include `--tail <numberOfLines>` to show only the last `<numberOfLines>` lines, and `--follow` to watch as new logs are added. Hub logs especially can provide a variety of useful information, as can viewing a pods' metadata with `describe`, as in `kubectl describe pod -n simple-example hub-787b87b8bd-fs6h8`, especially the output listed in the `events` section. 

We can also log into a pod to interact with the filesystem directly. The general syntax is

```bash
kubectl exec -n <hubName> -it <podName> -- <command>
```

This can be especially useful for logging into the NFS server pods to access user data directly (as root in this case), for example with

```bash
kubectl exec -n example-simple -it nfs-example-simplehomedrive-dep-0 -- /bin/bash
```
The NFS server exports the `/nfsshare` directory, and this can provide a means to offload data to another server or external system via `scp` or similar (you may need to install `scp` or the tool you wish to use first). 

Finally, to delete a pod use

```bash
kubectl delete pod -n <hubName> <podName>
```

Removing user-server pods this way stops their processes and turns off the server, much as if the server had died via more natural means. However, pods controlled by a a kubernetes replicaset or similar will auto-restart (possibly with a new randomized name). For example, you can delete the hub pod, and use `kubectl get pods -n <hubName>` to watch as kubernetes starts another to take its place. This doesn't even interrupt ongoing user servers and their work and access! (Though the hub pod controls login, so logging in will be temporarily affected while the new hub pod comes online). Try it! (Warning: theoretically removing the NFS server pod also causes it to restart with user data intact, but we haven't tested this. Additionally, it will likely cause other pods--specifically the hub and user pods--to hang as they lose their NFS mount.)


## Cost Evaluation

The cost of running DS@OSU is difficult to predict exactly, due to autoscaling depending actual usage and demand over time. To make matters worse, although both the scheduler and autoscaler are designed to maximize resource utilization, it will never be 100%--a single compute node (cloud VM) may reliably cost $0.30/hr, but in one hour it might be 90% used by 24 students from 5 different classes, and in the next may be only 20% used by 4 students from a single class. Only post-hoc cost breakdowns could reliably factor out these costs accurately on a per-class or per-user basis, and we do not yet have tools designed to do so. One could of course isolate clusters (or even nodepools within a cluster) as cost-accounting units, but doing so hobbles the ability of the scheduler and autoscaler to most efficiently allocate resources and save on costs. These are options, however, for those needing strictly isolated accounting. 

### Base Cluster Cost

All that said, we can compute the rough **base cost** for running a cluster on AWS supporting a minimal number of students, and then attempt to describe additional costs as usage grows based on hypothetical usage patterns. 

As mentioned elsewhere, DS@OSU currently only supports AWS. While the below doesn't cover every cost item involved, it does hit the top items, including the AWS EKS service, supporting networking services (load balancer, NAT gateway), a cluster support tooling node (for ingress, autoscaler, scheduler, etc), one "hub control plane" node (for hub-central resources like login processes and proxies), and one "user node" to host user servers. 

Costs shown are for the `us-west-2` AWS region as of 6/8/2021 and we consider 1 month to be 28 days (4 weeks).

| AWS Resource | Description | ~ Cost in $/mo (4 weeks) |
| --- | --- | --- | 
| AWS EKS | Kubernetes Cluster Service | 67.20 | 
| Load Balancer (Classic) | Networking | 16.80 |
| NAT Gateway | Networking | 30.24 |
| t3a.large w/ 20G EBS Storage | Cluster Tooling | 52.53 |
| t3a.large w/ 60G EBS Storage | Hub Control Plane | 56.53 |
| t3a.large w/ 60G EBS Storage | User Node | 56.53 |
|    |    |  **279.83** |

Note that the last three costs can be reduced by up to 50% by utilizing reserved instances on AWS (with between 1 and 3 year reservations) rather than on-demand pricing. 

This cluster and the primary user-facing resource (the t3a.large User Node instance with 2 CPUs and 8G of RAM) can support up to 16 simultaneous users performing basic coding and computation (i.e., 12.5% of a CPU core and 0.5G RAM usage), but this does not account for user data storage (at $0.10/GB/Month on AWS EBS) or data transfer (~ 0.06 per GB through the NAT Gateway and Load Balancer). 

### Multiple Clusters and Other Costs

From a system administration perspective we recommend running multiple clusters whenever it makes sense to do so: one 'production' cluster for hosting actual users, and another 'development' cluster for testing and practicing potentially disruptive management operations (e.g. software updates, practicing restoring data backups, etc). Finally, don't forget to factor in personnel costs, as managing DS@OSU requires at least basic familiarity with many in-demand skills including Docker, Kubernetes, and AWS. 

### Cost Per Student?

Estimating additional costs as usage scales to dozens of classes and hundreds or thousands of users depends almost entirely on the composition of work and usage. For light work a t3a.large node as described above can support up to 16 users simultaneously without difficulty, but for heavier classes where we gaurantee more resources per user that number will be reduced. While most costs beyond the "base" above can be computed per-user, others are at the hub/class level. Every hub for example requires 1/16 a t3a.large "hub control plane" node (1/16 of $56.53, or $3.53, per month, but only if enough courses are running to get to 100% utilization of these), and courses with heavy data storage needs will require more storage and bandwidth (at $0.10/GB/month + ~$0.06/GB in transfer costs) that don't scale with the number of students directly.

#### Example 1

Let's consider a hypothetical large introduction to programming class for 400 students; here the instructor supposes they will want a single hub ($3.53/Mo) with 1G of storage per student ($0.10/Student/Month) and 20G extra as "buffer" ($2/Mo). For this workload (assuming 0.5G to 1G of RAM usage per student) the extra compute costs come out to between $0.0094 and $0.0047 per student, per hour, assuming 100% resource utilization (a `t3a.large` instance costs $0.0752/hr on-demand, and can host between 8 students at 1G of RAM each to 16 students at 0.5G RAM each). Let's assume $0.01/student/hr for simplicity and generosity. Resource utilization is never 100% (we're always paying for more than what we need), if we naively assume 50% utilization we'll double that to $0.02/student/hr. If we assume the average student actively works on the system for 6 hours per week, and account for their server running ~50% extra time while inactive, we'll suppose 10 hours per student per week at this cost, or ~$0.80/Student/Month. In summary, we'd estimate approximately $0.90/student/month for this course (storage plus compute) plus an extra ~$10/Month for the hub itself (buffer storage and hub control plane node assuming 50% utilization). 

#### Example 2

Let's consider another, a smaller 30 student class where students are to perform moderate bioinformatics analyses. The instructor wants to upload about 100G of data (costing about $6 in transfer fees), and expects the students to use around 20G of data each over the term; to provide a measure of safety we'll allocate the 100G (for a "base" hub cost of closer $15/Month) and 30G/Student ($0.30/Student/Month). The intructor plans to assign 4 hours of light computation homework per week (for which we'll use the same $0.02/Student/hr estimate with adjustment for inactivity, ~$0.48/Student/Month), as well as a weekly assignment that will require between 8 and 16G of RAM and run for up to 2 hours. These RAM requirements are significantly more expensive, but fortunately within the `t3a` node class the costs scale linearly, so we can expect the hourly costs to be 16X as much, or ~$0.32/Student/hr, and with the same adjustments we can figure these extra assignments will cost $3.84/Student/Month ($0.32 * 1.5 * 2 hrs/week). To summarize, we estimate this hub to cost $6 to set up and $15/Month to run, as well as $4.16/Student/Month.

#### GPUs

Lastly, while DS@OSU provides experimental support for GPU-based compute (for e.g. deep learning), these resources aren't cheap, at minimum $0.90 *per hour* for a single GPU as part of a `g4dn.2xlarge` AWS node. 

### Cost Wrapup

Hopefully it's clear that the cost estimates above will inevitably be wildly inaccurate: they simply require too many assumptions about usage patterns and we've simplified the dynamic nature of the system considerably. Consider that in the middle of the night resource usage is very low, but we always leave some "lights on" for students wishing to working late. The assumption of 50% utilization is a guess (though not too far from reality in our experience), and in reality varies considerably on time of day and overall cluster size. A cluster with 3 classes and 100 users will likely be low utilization efficiency most of the time with peaks of higher efficiency, while one with 50 classes and 1000 users should see the overall utilization be higher and smoother. 

For what it's worth, the Z2JH project (the basis for DS@OSU) has collected some cost information [here](https://zero-to-jupyterhub.readthedocs.io/en/latest/administrator/cost.html). You may also find useful the [cost breakdown](https://github.com/jupyterhub/binder-billing) for mybinder.org, a large-scale system with similar architecture (but run primarily on Google GCP).

In any case, the autoscaling nature of DS@OSU provide an opportunity for reasonable base system costs (on the order of a several hundred dollar per month) and efficient per-student costs (on the order of dollars per month per student). Still, it is wise to consider the personnel costs of running a complex kubernetes-based service, as well as ancillary IT costs such as development and testing clusters, demo hubs, and so on. 

## Security

DS@OSU was designed for light security requirements--authentication when using Canvas leverages Canvas' security and access measures, and all traffic in and out of the cluster is encrypted (TLS). Traffic inside the cluster pertaining to data transfer is unencrypted (since we use in-cluster NFS mounts), but permissions are used to prevent unauthorized data access. 

In the interest of full disclosure, there are some security considerations worth noting. In most applications of Docker or Kubernetes, containers are not normally run with the `root` user. DS@OSU does run containers with `root`, but then `sudo` is used to drop permissions before starting the user-facing web interface. There are two reasons for this: first, running the container as `root` before dropping priveledges supports the admin/user permissions distinction. Second, the shared data space is mounted via NFS, which can only be done by `root` from the container via `mount` (see next paragraph), and furthermore requires the container be given the `CAP_SYS_ADMIN` [capability](https://opensource.com/business/14/9/security-for-docker). 

This latter reason might be avoided on infrastructures other than AWS; because kubernetes supports NFS-mounted volumes as a native volume type, the container *shouldn't* need to run `mount` itself. However, this is only possible when the cluster *nodes* can resolve DNS entries in the cluster itself (since the NFS servers are in-cluster and managed by kubernetes, but kubernetes NFS volume mounts are resolved by the host OS). On GCP it appears cluster nodes do have kubedns resolution, whereas on AWS they do/did not. 

The former reason might be also be difficult to avoid, but at least this reason doesn't require `CAP_SYS_ADMIN`. The NFS mount points are not protected by `root_squash` as permissions are configured via root-owned files in the shared NFS space (and written by the containers prior to permissions dropping). On the whole, this means that should a user find a `root`-level escalation exploit, they could in theory re-mount the shared data space for their hub with read+write as root as well. Given that NFS mounts are available cluster-wide, such an exploit could permit re-mounting *any* hub's data. Kubernetes network policies that restrict traffic between namespaces should negate this risk but haven't been implemented yet.

It is thus important to be aware of potential root-level exploits and keep user-facing docker images up to date accordingly. We continue to investigate alternatives for shared data spaces (especially first-class kubernetes RWX volumes) and rootless permission attribution (for which init containers may be a solution).

