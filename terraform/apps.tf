resource "kubernetes_manifest" "apps" {
  depends_on = [helm_release.argocd, kubernetes_secret_v1.repo_raspi5]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"

    metadata = {
      name      = "apps"
      namespace = "argocd"
    }

    spec = {
      generators = [{
        git = {
          repoURL     = local.repo_url
          revision    = "HEAD"
          directories = [{ path = "apps/*" }]
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

}
