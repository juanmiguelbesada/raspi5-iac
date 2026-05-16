resource "kubernetes_namespace_v1" "openclaw" {
  metadata {
    name = "openclaw"
  }
}

resource "kubernetes_secret_v1" "openclaw" {
  metadata {
    name      = "openclaw-secrets"
    namespace = kubernetes_namespace_v1.openclaw.metadata[0].name
  }
  data = {
    "opencode-zen-api-key" = var.opencode_zen_api_key
    "openrouter-api-key"   = var.openrouter_api_key
    "telegram-bot-token"   = var.telegram_bot_token
  }
}
