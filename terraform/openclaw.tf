resource "kubernetes_namespace_v1" "openclaw" {
  metadata {
    name = "openclaw"
  }
}

# Auto-generated gateway token for Control UI auth
resource "random_password" "openclaw_gateway_token" {
  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "openclaw" {
  metadata {
    name      = "openclaw-secrets"
    namespace = kubernetes_namespace_v1.openclaw.metadata[0].name
  }
  data = {
    "openrouter-api-key"     = var.openrouter_api_key
    "telegram-bot-token"     = var.telegram_bot_token
    "openclaw-gateway-token" = random_password.openclaw_gateway_token.result
  }
}
