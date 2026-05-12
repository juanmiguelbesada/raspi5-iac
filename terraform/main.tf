terraform {
  required_version = ">= 1.5"

  backend "kubernetes" {
    config_path    = "~/.kube/config"
    secret_suffix  = "raspi5"
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

locals {
  domain   = "192.168.1.155.sslip.io"
  repo_url = "https://github.com/juanmiguelbesada/raspi5.git"
}
