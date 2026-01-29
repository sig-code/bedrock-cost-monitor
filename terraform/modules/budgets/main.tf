data "aws_caller_identity" "current" {}

# AWS Budget for Bedrock service only
resource "aws_budgets_budget" "bedrock_monthly" {
  name              = var.budget_name
  budget_type       = "COST"
  limit_amount      = var.budget_amount
  limit_unit        = "USD"
  time_period_start = var.budget_start_date
  time_unit         = "MONTHLY"

  # Filter to monitor only Amazon Bedrock service
  cost_filter {
    name = "Service"
    values = [
      "Amazon Bedrock"
    ]
  }

  # 30% threshold notification
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 30
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.sns_topic_arn]
  }

  # 50% threshold notification
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.sns_topic_arn]
  }

  # 80% threshold notification
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.sns_topic_arn]
  }

  # 100% threshold notification
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.sns_topic_arn]
  }

  # Optional email notification for 100% threshold
  dynamic "notification" {
    for_each = var.notification_email != "" ? [1] : []
    content {
      comparison_operator = "GREATER_THAN"
      threshold          = 100
      threshold_type     = "PERCENTAGE"
      notification_type  = "ACTUAL"
      subscriber_email_addresses = [var.notification_email]
    }
  }
}
