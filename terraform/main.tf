// Added variables and locals to support both KinD and external cluster modes
variable "cluster_mode" {
  description = "Select 'kind' to create a local KinD cluster, or 'external' to use your current kubeconfig (e.g., Minikube)."
  type        = string
  default     = "kind"
  validation {
    condition     = contains(["kind", "external"], var.cluster_mode)
    error_message = "cluster_mode must be 'kind' or 'external'."
  }
}

variable "external_kubeconfig_path" {
  description = "Path to kubeconfig when cluster_mode is 'external'. If empty, defaults to ~/.kube/config."
  type        = string
  default     = ""
}

locals {
  kubeconfig_path = var.cluster_mode == "kind" ? pathexpand("${path.module}/kubeconfig") : (
    var.external_kubeconfig_path != "" ? pathexpand(var.external_kubeconfig_path) : pathexpand("~/.kube/config")
  )
}

provider "kind" {}

resource "kind_cluster" "hextris" {
  count           = var.cluster_mode == "kind" ? 1 : 0
  name            = "hextris"
  node_image      = "kindest/node:v1.30.0"
  kubeconfig_path = local.kubeconfig_path
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      # Map container port 80 to host port 8080 for access to NodePort 30080 via kind's control-plane
      extra_port_mappings {
        container_port = 80
        host_port      = 8080
      }
      extra_port_mappings {
        container_port = 30080
        host_port      = 30080
      }
    }
    node {
      role = "worker"
    }
  }
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}

output "kubeconfig_path" {
  value = local.kubeconfig_path
}

resource "null_resource" "build_image" {
  count = var.cluster_mode == "kind" ? 1 : 0
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "docker build -t hextris:local ${abspath("${path.module}/..")}"
  }
}

resource "null_resource" "load_image" {
  count      = var.cluster_mode == "kind" ? 1 : 0
  depends_on = [kind_cluster.hextris, null_resource.build_image]

  triggers = {
    image = "hextris:local"
  }

  provisioner "local-exec" {
    command = "kind load docker-image hextris:local --name hextris"
  }
}

resource "helm_release" "hextris" {
  name             = "hextris"
  namespace        = "hextris"
  create_namespace = true

  chart = abspath("${path.module}/../charts/hextris")

  wait            = true
  cleanup_on_fail = true

  // Static depends_on to satisfy Terraform; resources may have count = 0 in external mode
  depends_on = [kind_cluster.hextris, null_resource.load_image]

  // Use the locally built image name/tag in both modes by default
  set {
    name  = "image.repository"
    value = "hextris"
  }
  set {
    name  = "image.tag"
    value = "local"
  }
}

output "cluster_endpoint" {
  value = var.cluster_mode == "kind" ? kind_cluster.hextris[0].endpoint : "using-external-cluster"
}