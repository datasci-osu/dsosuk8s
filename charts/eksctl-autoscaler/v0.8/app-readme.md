# EKSCtl Autoscaler

Autoscaler for eksctl-based clusters, based on https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws, specifically auto-discovery but using kubernetes.io/cluster/eksdevd tag instead of adding a special tag as indicated by the docs.

