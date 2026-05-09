terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

module "hello-world" {
  source = "./modules/k3s-app"

  name     = "hello-world"
  image    = "nginx:alpine"
  hostname = "hello-world.192.168.1.155.sslip.io"
}
