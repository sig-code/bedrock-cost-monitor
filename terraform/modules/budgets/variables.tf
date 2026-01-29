variable "budget_name" {
  description = "Name of the AWS Budget"
  type        = string
  default     = "bedrock-monthly-budget"
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = string
}

variable "budget_start_date" {
  description = "Budget start date in format YYYY-MM-DD_HH:MM"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of SNS topic for budget notifications"
  type        = string
}

variable "notification_email" {
  description = "Email address for budget notifications (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to budget"
  type        = map(string)
  default     = {}
}
