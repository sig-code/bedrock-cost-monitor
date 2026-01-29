output "budget_name" {
  description = "Name of the created budget"
  value       = module.budgets.budget_name
}

output "budget_arn" {
  description = "ARN of the created budget"
  value       = module.budgets.budget_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for budget alerts"
  value       = module.sns.topic_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.function_name
}

output "lambda_log_group" {
  description = "CloudWatch Log Group for Lambda function"
  value       = module.lambda.log_group_name
}

output "ssm_parameter_name" {
  description = "Name of the SSM parameter storing Slack webhook URL"
  value       = module.ssm.parameter_name
}
