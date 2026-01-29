output "topic_arn" {
  description = "ARN of the SNS topic for budget alerts"
  value       = aws_sns_topic.budget_alerts.arn
}

output "topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.budget_alerts.name
}
