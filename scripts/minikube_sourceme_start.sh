
if ! minikube status | grep -q 'apiserver: Running'; then
  echo "Minikube not running, starting with 4 CPUs and 4G RAM, please wait..."
  minikube addons enable ingress
  minikube addons enable default-storageclass
  minikube addons enable registry
  minikube addons enable storage-provisioner

  minikube start --vm-driver virtualbox --kubernetes-version=1.15.5 --cpus 4 --memory 4000mb
fi

echo "Configuring minikube."

ETC_HOSTS_KUBERNETES_IP=`cat /etc/hosts | grep kubernetes.local | cut -f 1`
MINIKUBE_IP=`minikube ip`

if [[ "$ETC_HOSTS_KUBERNETES_IP" != "$MINIKUBE_IP" ]]; then
  echo "Need to update kubernetes.local entry in /etc/hosts to point to minikube VM, plese provide sudo password: "
  sudo sed -i -e 's/.*kubernetes.local$/'$(minikube ip)$'\tkubernetes.local/' /etc/hosts
fi

# set docker to docker inside the minikube VM
eval $(minikube docker-env)

# sigh... https://github.com/kubernetes/minikube/issues/2061
DSTR=$(date -u); minikube ssh "sudo date --set=\"$DSTR\""

echo "Minikube configured and available at kubernetes.local; docker set to build and push from the minikube VM, kubectl and helm refer to minikube."
