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
