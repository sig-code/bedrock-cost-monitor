variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = string
  default     = "200"
}

variable "budget_start_date" {
  description = "Budget start date in format YYYY-MM-DD_HH:MM"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL for cost notifications"
  type        = string
  sensitive   = true
}

variable "notification_email" {
  description = "Optional email address for budget notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
