locals {
  cloudflare_zone_name = "juanmiguelbesada.com"
}

# Tunnel secret used to authenticate this tunnel with the Cloudflare edge
# Must be at least 32 bytes, provided as base64
resource "random_password" "tunnel_secret" {
  length  = 32
  special = false
}

# The tunnel itself — a logical tunnel on the Cloudflare side
resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id    = var.cloudflare_account_id
  name          = "raspi5"
  tunnel_secret = base64encode(random_password.tunnel_secret.result)
}

# Retrieve the JWT token that cloudflared uses to authenticate
data "cloudflare_zero_trust_tunnel_cloudflared_token" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

# Routes all tunnel traffic to the in-cluster Traefik service.
# Traefik handles host-based routing via Ingress resources.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id

  config = {
    ingress = [
      {
        service = "http://traefik.kube-system.svc:80"
      }
    ]
  }
}

# Look up the Cloudflare zone by domain name
data "cloudflare_zone" "main" {
  filter = {
    name = local.cloudflare_zone_name
  }
}

# Wildcard CNAME so every *.raspi5.juanmiguelbesada.com resolves through the tunnel
resource "cloudflare_dns_record" "wildcard" {
  zone_id = data.cloudflare_zone.main.id
  name    = "*.raspi5"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "kubernetes_namespace_v1" "cloudflare_tunnel" {
  metadata {
    name = "cloudflare-tunnel"
  }
}

# Store the tunnel token so the cloudflared pod can authenticate
resource "kubernetes_secret_v1" "cloudflare_tunnel" {
  depends_on = [kubernetes_namespace_v1.cloudflare_tunnel]

  metadata {
    name      = "cloudflare-tunnel"
    namespace = "cloudflare-tunnel"
  }

  data = {
    token = data.cloudflare_zero_trust_tunnel_cloudflared_token.main.token
  }

  type = "Opaque"
}

# cloudflared connects outbound to Cloudflare edge and forwards traffic to Traefik
resource "kubernetes_deployment_v1" "cloudflared" {
  depends_on = [kubernetes_secret_v1.cloudflare_tunnel]

  metadata {
    name      = "cloudflared"
    namespace = "cloudflare-tunnel"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:latest"

          args = [
            "tunnel",
            "run",
            "--token",
            "$(TUNNEL_TOKEN)",
          ]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = "cloudflare-tunnel"
                key  = "token"
              }
            }
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }

        # If the node is rebooted or k3s restarts, the tunnel comes back automatically
        restart_policy = "Always"
      }
    }
  }
}
