resource "helm_release" "apps" {
  depends_on = [helm_release.argocd, kubernetes_secret_v1.repo_raspi5]
  name       = "apps"
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
          path           = "apps/hello-world"
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
