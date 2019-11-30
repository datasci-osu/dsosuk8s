echo "Unconfiguring minikube..."

eval $(minikube docker-env -u)
minikube stop

echo "Minikube unconfigured: minikube VM stopped; docker, kubectl, and helm no longer refer to minikube VM."
