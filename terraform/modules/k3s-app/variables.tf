variable "name" {
  description = "App name"
  type        = string
}

variable "image" {
  description = "Container image"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace (defaults to app name)"
  type        = string
  default     = null
}

variable "replicas" {
  description = "Number of pod replicas"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 80
}

variable "service_port" {
  description = "Service port"
  type        = number
  default     = 80
}

variable "hostname" {
  description = "Ingress hostname (no ingress if null)"
  type        = string
  default     = null
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

variable "ingress_annotations" {
  description = "Ingress annotations"
  type        = map(string)
  default     = {}
}
