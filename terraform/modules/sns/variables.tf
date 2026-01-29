variable "topic_name" {
  description = "Name of the SNS topic for budget alerts"
  type        = string
  default     = "bedrock-budget-alerts"
}

variable "tags" {
  description = "Tags to apply to SNS topic"
  type        = map(string)
  default     = {}
}
