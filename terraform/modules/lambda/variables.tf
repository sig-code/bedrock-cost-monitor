variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "bedrock-cost-notifier"
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic to subscribe to"
  type        = string
}

variable "ssm_parameter_name" {
  description = "Name of SSM parameter containing Slack webhook URL"
  type        = string
}

variable "ssm_parameter_arn" {
  description = "ARN of SSM parameter containing Slack webhook URL"
  type        = string
}

variable "tags" {
  description = "Tags to apply to Lambda resources"
  type        = map(string)
  default     = {}
}
