# Hextris on Kubernetes with Terraform + Helm (Local KinD)

This repository provisions a local Kubernetes cluster (KinD) using Terraform, builds a Docker image that serves the Hextris game via Nginx, and deploys it using a Helm chart.

## Prerequisites
- Docker Desktop (or Docker Engine)
- Terraform >= 1.4
- kubectl
- kind
- helm

## Quick Start (com scripts)

For those who just want to quickly run/delete using Minikube + Terraform (external mode):

- Upload the game: `./hextris.sh up` (the script prints the access URL at the end)
- View status: `./hextris.sh status`
- Delete the game: `./hextris.sh down` or `./hextris-destroy.sh`

Notes:
- Requires minikube, kubectl, terraform, helm, and docker installed on the host.
- The `hextris.sh up` script builds the `hextris:local` image inside Minikube's Docker and applies Terraform with `-var='cluster_mode=external``.
- To manually open the URL, you can use: `minikube service hextris -n hextris --url` or `echo "http://$(minikube ip):30080"`.

## Project Structure
- terraform/: Terraform scripts to create KinD cluster and deploy Helm release
- charts/hextris/: Helm chart for Hextris (Deployment + NodePort Service)
- Dockerfile: Builds Nginx image with Hextris static site

## Steps

1) Initialize and create the KinD cluster

```
cd terraform
terraform init
terraform apply -auto-approve
```

Terraform outputs a kubeconfig at `terraform/kubeconfig`. You may export it:

```
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

2) Build the Hextris image and load into KinD (handled by Terraform)

The Terraform configuration includes steps to build the Docker image and load it into the KinD cluster. It tags the image as `hextris:local` and loads it with `kind load docker-image`.

3) Deploy Hextris Helm chart

Terraform will deploy the Helm chart automatically after the image is loaded.
Alternatively, you can deploy manually:

```
helm upgrade --install hextris ./charts/hextris --namespace hextris --create-namespace \
  --set image.repository=hextris --set image.tag=local
```

4) Access the app

We expose a NodePort service on port 30080. With the cluster created by Terraform, you can access at:

- http://localhost:30080

If access does not work (platform-dependent), you can also port-forward:

```
kubectl -n hextris port-forward svc/hextris 8080:80
open http://localhost:8080
```

## Alternative: Use Minikube without Docker Desktop (Terraform external mode)

If you don’t have Docker Desktop (required by KinD), you can deploy to Minikube using Terraform’s external mode.

1) Start Minikube

```
minikube start --driver=hyperkit --cpus=2 --memory=4096 --disk-size=20g
```

2) Build the image inside Minikube’s Docker

```
eval $(minikube docker-env)
docker build -t hextris:local .
```

3) Deploy with Terraform in external mode

```
cd terraform
terraform init
terraform apply -auto-approve -var='cluster_mode=external'
```

4) Access the app

```
# Option A (prints a usable URL):
minikube service hextris -n hextris --url

# Option B (NodePort via Minikube IP):
echo "http://$(minikube ip):30080"
```

Notes:
- cluster_mode defaults to "kind". Passing -var='cluster_mode=external' tells Terraform to use your current kubeconfig (Minikube) and skip creating KinD or loading images via kind.
- If you use Option B and your firewall blocks the IP, use port-forward instead:

```
kubectl -n hextris port-forward svc/hextris 8080:80
open http://localhost:8080
```

## Clean up

Choose the cleanup path that matches how you ran the project.

1) If you used Terraform + KinD (recommended path in this repo)

```
cd terraform
terraform destroy -auto-approve
# optional: remove the generated kubeconfig file
rm -f kubeconfig
```

2) If you deployed manually with Minikube + Helm

```
# Remove the Helm release and namespace
helm uninstall hextris -n hextris || true
kubectl delete ns hextris --ignore-not-found

# Delete the Minikube cluster
minikube delete

# If you previously pointed Docker to Minikube, reset your shell env (optional)
eval $(minikube docker-env -u)
```

3) Optional: remove the local Docker image (if you built it against your host Docker)

```
docker rmi hextris:local || true
```

## My utilized References:
- Hextris repo: https://github.com/Hextris/hextris
- Terraform kind provider examples: tehcyx/kind provider docs