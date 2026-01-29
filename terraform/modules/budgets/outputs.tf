output "budget_name" {
  description = "Name of the created budget"
  value       = aws_budgets_budget.bedrock_monthly.name
}

output "budget_id" {
  description = "ID of the created budget"
  value       = aws_budgets_budget.bedrock_monthly.id
}

output "budget_arn" {
  description = "ARN of the created budget"
  value       = aws_budgets_budget.bedrock_monthly.arn
}
