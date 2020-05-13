# AWS EKS Clusters with `eksctl`

`eksctl` is an AWS-blessed 3rd party utility for deploying kubernetes clusters on EKS. Using it requires 
an AWS account with appropriate permissions, the `aws` command-line utility (configured to access an appropriate [profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
via access key) and `kubectl`. 

## Cluster Deployment and Configuration

EKS clusters deployed by `eksctl` (or created with the AWS console) are rather bare -- they don't come with some important kubernetes tools,
specifically a cluster-autoscaler or ingress controller. This may as well be, as we've created special deployments of these services for use with the JupyterHub chart (allowing multiple hubs to share the same hostname via nginx-ingress master/minion annotations). 

Deploying and user a cluster assumes you have a domain name for the cluster (e.g. `clusterA.datasci.oregonstate.edu`) which can be CNAMEd to an AWS load balancer, and a corresponding certificate (cert and key files). 

(Note that this configuration does SSL termination at the ingress controller, ie, on first entry to the cluster.)

First, cluster creation and import:

0. Make sure your `aws` CLI credentials are set - `source <repo>/scripts/source_env.sh` is a helper for this and a few other aliases.
1. Deploy the cluster with `eksctl create cluster -f <clusterconfig.yaml>`
2. Get coffee - EKS clusters take forever.
3. Check that you can see the nodes and are talking to the cluster just created with `kubectl get nodes` and `kubectl config current-context`

Following this, the cluster can be bootstrapped with `scripts/bootstrap_cluster_deploy.sh <vars>` - see `cluster_bootstrap.vars` in `deployments/example.clustere.edu` for an example, and note that the domain name and other information will need to be set.


## Cluster Config Details

While `eksctl` can deploy basic clusters with minimal command-line arguments, it can also deploy clusters with configuration details 
provided by a `.yaml`. file, see the included files for structural details. 

Breaking down by specific topic:

### nodeGroups vs managedNodeGroups (vs Fargate)

Each entry here defines an autoscaling nodegroup, with "taints" (sort of like node tags) specific to sending Core and User jupyterhub pods to 
specific nodegroups. 

EKS recently added ["managed"](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) nodegroups, 
which provide a few nice features compared to standard nodegroups. These however do not support some of the necessary customizations specified in the
configuration YAML files here, so we don't use them. 

In particular, they don't yet support taints ([ref](https://eksctl.io/usage/eks-managed-nodegroups/)) required to assign JupyterHub core components to the correct nodegroup (see discussion on GitHub
[here](https://github.com/jupyterhub/zero-to-jupyterhub-k8s/issues/299) and [here](https://github.com/weaveworks/eksctl/pull/703) for support on non-managed
nodegroups). 

Second, managed nodegroups don't support user-data customizations (same ref), which we use to enable NFS on host nodes in the `preBootstrapCommands:` section. 

AWS Fargate is a managed container service that can be used to host EKS cluster (and is deployable by `eksctl`) without considering nodes at all. 
Unfortunately there are some steep limitations (see [Pricing and Limitations](https://aws.amazon.com/blogs/aws/amazon-eks-on-aws-fargate-now-generally-available/)),
including no support for persistent volumes, limited container resources, and no support for DaemonSets (used by JupyterHub core components) or
priveledge containers (used by NFS-serving StatefulSets). 



### Instance Types

Currently we are using `t3a.large` instances for "user" JH components (2 core, 8G RAM) and `t3a.medium` (2 core, 4G RAM) for "core" JH components. The
prometheus+grafana monitoring uses some resources on all nodes (approx. 0.5G RAM and 0.2 CPU), and more on one node (approx. 1G RAM and 1.1 CPU), so it may be worth
upgrading to `t3a.large` for core nodes as well, to be determined with more testing. (Between kubernetes system components and monitoring, the "base load"
for nodes isn't tiny; using larger instances reduces the relative share dedicated to cluster management, but increases granularity for user workload scaling.)

### Storage Gotchas

For per-Hub shared storage, we are currently using in-cluster NFS servers backed by EBS volumes, these are deployed by the "drive" Rancher application (aka chart) in the `charts` directory.  

These applications are deployed as StatefulSets of size 1, 
to prevent accidental data loss in the case of node or container crash, or accidental deletion of the servers. However, the nature of these EBS-backed
volumes is that they can get "stuck" if they are deleted *before* other components accessing them. (Though it's not unfixable.) See the `app-readme.md`
file in `charts/nfs-drive/latest/` for details. (Earlier iteractions deployed them as Deployments, meaning the volumes would be automatically removed
when the deployment was deleted. This should be reasonably safe as it reschedules in the event of node or container failure, and only doesn't protect
against accidental deletion via admin error.)

It is important to note that by default JuptyerHub (and all kubernetes applications deployed to EKS) use EBS-backed storage for persistent volumes, but,
EC2 instances are **[limited](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/volume_limits.html) in the number of EBS volumes that can be attached**. (28 for `t3a` types).
This is less of a concern in our architecture because we are utilizing a single PV per Hub - standard JupyterHub kubernetes deployments that deploy a PV
per user may be more prone to exceeding these limits. We specify some CPU and memory request for storage 

As noted above, `preBootstrapCommands` are used to enable NFS at the node level. 

Lastly, EBS volumes can be tranferred between nodes if needed when pods are moved or rescheduled (within and between nodegroups), but *not between availability zones*. Thus, the "core" nodegroup
is restricted to running in a single availabity zone, lest a pod hosting a volume be tranferred to a node in another AZ, and the EBS volumes cannot
attach. This also means that so long as we are using EBS-backed storage, the system cannot be high-availability in the sense of multi-availability-zone
or multi-region. (It may be possible to create multiple nodegroups, each limited to a different AZ ([ref](https://docs.aws.amazon.com/eks/latest/userguide/cluster-autoscaler.html)), but I've not explored this option and how it
may integrate with JH component scheduling.) 

We are using local storage of 30G per node for storing docker images etc., 20G fit but was getting a little tight during testing (perhaps only due to 
docker image churn during development). 

### Node Labels, Tags, and Taints

The main node label utilized by JupyterHub in scheduling components to the correct nodegroup is `hub.jupyter.org/node-purpose` (set to either `"core"`
or `"user"` - we also add a label for `nodegroup-role:`, either `"jhcontrolplane"`, `"jhusers"`, or `"clustertools"`, used by charts for targetting nodegroups. 

The `hub.jupyter.org/dedicated: user:NoSchedule` "taint" associated with the user nodegroup is important for JH's scheduling of user components.

### Scaling

The `minSize`, `maxSize`, and `desiredCapacity` define initial properties of the autoscaling groups - the cluster autoscaler is configured to read these. 
In some cases they can also be set from within the cluster autoscaler, but on AWS one *should adjust these settings on the EC2 console* (or the `aws` cli)
rather than from within-cluster (see first paragraph of Deployment Specification [here](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#deployment-specification)).

The cluster-autoscaler within the `charts` directory is set to use auto-discover (scale-from-zero not enabled), which requires the cluster name
(as set in the `eksctl` yaml) to ensure that the autoscaler only attempts to autoscale the cluster in question. ([ref](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#auto-discovery-setup))


## Cluster Fixing & Adjusting

more to write...
