terraform {
  required_version = ">= 1.5"
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
  domain = "192.168.1.155.sslip.io"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  values = [yamlencode({
    global = {
      domain = "argocd.${local.domain}"
    }
    configs = {
      params = {
        "server.insecure" = true
      }
    }
    server = {
      ingress = {
        enabled          = true
        ingressClassName = "traefik"
        hosts = ["argocd.${local.domain}"]
      }
    }
  })]
}

resource "kubernetes_secret_v1" "repo_raspi5" {
  depends_on = [helm_release.argocd]

  metadata {
    name      = "repo-raspi5"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type     = "git"
    url      = "https://github.com/juanmiguelbesada/raspi5.git"
    username = "juanmiguelbesada"
    password = var.github_token
  }
}

resource "helm_release" "hello_world" {
  depends_on = [helm_release.argocd, kubernetes_secret_v1.repo_raspi5]
  name       = "hello-world"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [yamlencode({
    applications = {
      hello-world = {
        namespace = "argocd"
        additionalAnnotations = {
          "helm.sh/resource-policy" = "keep"
        }
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project = "default"
        source = {
          repoURL        = "https://github.com/juanmiguelbesada/raspi5.git"
          targetRevision = "HEAD"
          path           = "gitops/hello-world"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "hello-world"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
          syncOptions = ["CreateNamespace=true"]
        }
      }
    }
  })]
}
