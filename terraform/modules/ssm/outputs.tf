output "parameter_name" {
  description = "Name of the SSM parameter storing Slack webhook URL"
  value       = aws_ssm_parameter.slack_webhook_url.name
}

output "parameter_arn" {
  description = "ARN of the SSM parameter"
  value       = aws_ssm_parameter.slack_webhook_url.arn
}
