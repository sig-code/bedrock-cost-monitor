variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL for cost notifications"
  type        = string
  sensitive   = true
}

variable "parameter_name" {
  description = "SSM Parameter Store name for Slack webhook URL"
  type        = string
  default     = "/bedrock-cost-monitor/slack-webhook-url"
}

variable "tags" {
  description = "Tags to apply to SSM parameter"
  type        = map(string)
  default     = {}
}
