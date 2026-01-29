resource "aws_ssm_parameter" "slack_webhook_url" {
  name        = var.parameter_name
  description = "Slack Incoming Webhook URL for Bedrock cost notifications"
  type        = "SecureString"
  value       = var.slack_webhook_url

  tags = merge(
    var.tags,
    {
      Name = "bedrock-cost-monitor-webhook"
    }
  )
}
