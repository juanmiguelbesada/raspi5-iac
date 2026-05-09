output "namespace" {
  value = local.namespace
}

output "deployment_name" {
  value = kubernetes_deployment_v1.this.metadata[0].name
}

output "service_name" {
  value = kubernetes_service_v1.this.metadata[0].name
}

output "ingress_hostname" {
  value = var.hostname != null ? kubernetes_ingress_v1.this[0].spec[0].rule[0].host : null
}
