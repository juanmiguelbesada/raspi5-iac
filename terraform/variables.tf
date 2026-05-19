variable "github_token" {
  description = "GitHub classic PAT with repo scope (https://github.com/settings/tokens)"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Tunnel:Edit, DNS:Edit, and Zone:Read permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (from dashboard)"
  type        = string
}

variable "openrouter_api_key" {
  description = "OpenRouter API key (https://openrouter.ai/keys)"
  type        = string
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token from @BotFather"
  type        = string
  sensitive   = true
}

