# Drive

Provides storage that can be used by applications, by spinning up an NFS server backed by a 
persistent volume. The DNS name is the application deployment name. 

Applications must be specially built to make use of this
storage (ie, they must mount the NFS share via it's name, rather than use the NFS kubernetes
volume type, due to this issue: https://github.com/kubernetes/kubernetes/issues/44528). 

*Warning*: In it's current configuration, "deleting" a drive application will *not* also remove the associated PVC and PV,
for safety. That needs to be done separately. In the Rancher UI, in the project where the volume was created, navigate to Resources ->
Workloads, and select the Volumes tab. They can be deleted from there. (They will be stuck in "Removing" state until the app itself is 
deleted; if any other applications (like jupyter users) are accessing the drive, then the behavior is unknown yet.)

 
