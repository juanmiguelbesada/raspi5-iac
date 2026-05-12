resource "helm_release" "apps" {
  depends_on = [helm_release.argocd, kubernetes_secret_v1.repo_raspi5]
  name       = "apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [yamlencode({
    applicationSets = {
      apps = {
        generators = [{
          git = {
            repoURL      = local.repo_url
            revision     = "HEAD"
            directories  = [{ path = "apps/*" }]
          }
        }]
        template = {
          metadata = {
            name = "{{path.basename}}"
          }
          spec = {
            project = "default"
            source = {
              repoURL        = local.repo_url
              targetRevision = "HEAD"
              path           = "{{path}}"
            }
            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = "{{path.basename}}"
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
      }
    }
  })]
}
