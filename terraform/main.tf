provider "kind" {}

resource "kind_cluster" "hextris" {
  name            = "hextris"
  node_image      = "kindest/node:v1.30.0"
  kubeconfig_path = pathexpand("${path.module}/kubeconfig")
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
  config_path = pathexpand("${path.module}/kubeconfig")
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("${path.module}/kubeconfig")
  }
}

output "kubeconfig_path" {
  value = pathexpand("${path.module}/kubeconfig")
}

resource "null_resource" "build_image" {
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "docker build -t hextris:local ${abspath("${path.module}/..")}"
  }
}

resource "null_resource" "load_image" {
  depends_on = [kind_cluster.hextris, null_resource.build_image]

  triggers = {
    image = "hextris:local"
  }

  provisioner "local-exec" {
    command = "kind load docker-image hextris:local --name ${kind_cluster.hextris.name}"
  }
}

resource "helm_release" "hextris" {
  name             = "hextris"
  namespace        = "hextris"
  create_namespace = true

  chart = abspath("${path.module}/../charts/hextris")

  wait       = true
  cleanup_on_fail = true

  depends_on = [kind_cluster.hextris, null_resource.load_image]
}

output "cluster_endpoint" {
  value = kind_cluster.hextris.endpoint
}