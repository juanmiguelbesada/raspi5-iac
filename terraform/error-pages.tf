resource "helm_release" "error_pages" {
  name             = "error-pages"
  repository       = "oci://ghcr.io/tarampampam/error-pages/charts"
  chart            = "error-pages"
  version          = "4.2.0"
  namespace        = "error-pages"
  create_namespace = true

  values = [yamlencode({
    config = {
      htmlTemplate = {
        name = "app-down"
      }
      homepageUrl      = "https://${local.public_domain}"
      sendSameHttpCode = true
    }
  })]
}

resource "kubernetes_manifest" "error_pages_catch_all" {
  depends_on = [helm_release.error_pages]

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "error-pages-catch-all"
      namespace = "error-pages"
    }
    spec = {
      entryPoints = ["web"]
      routes = [{
        match    = "HostRegexp(`.+`)"
        kind     = "Rule"
        priority = 1
        services = [{
          name = "error-pages"
          port = 8080
        }]
      }]
    }
  }
}
