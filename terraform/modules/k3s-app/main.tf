locals {
  namespace = var.namespace != null ? var.namespace : var.name
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = var.name
      }
    }
    template {
      metadata {
        labels = {
          app = var.name
        }
      }
      spec {
        container {
          image = var.image
          name  = var.name
          port {
            container_port = var.container_port
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "this" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    selector = {
      app = var.name
    }
    port {
      port        = var.service_port
      target_port = var.container_port
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "this" {
  count = var.hostname != null ? 1 : 0

  metadata {
    name        = var.name
    namespace   = kubernetes_namespace_v1.this.metadata[0].name
    annotations = var.ingress_annotations
  }
  spec {
    ingress_class_name = var.ingress_class_name
    rule {
      host = var.hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.this.metadata[0].name
              port {
                number = var.service_port
              }
            }
          }
        }
      }
    }
  }
}
