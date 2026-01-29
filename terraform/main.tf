terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = "bedrock-cost-monitor"
        Environment = var.environment
        ManagedBy   = "Terraform"
      },
      var.tags
    )
  }
}

locals {
  common_tags = {
    Project     = "bedrock-cost-monitor"
    Environment = var.environment
  }
}

# SSM Parameter Store for Slack Webhook URL
module "ssm" {
  source = "./modules/ssm"

  slack_webhook_url = var.slack_webhook_url
  tags             = local.common_tags
}

# SNS Topic for Budget Alerts
module "sns" {
  source = "./modules/sns"

  topic_name = "bedrock-budget-alerts"
  tags      = local.common_tags
}

# Lambda Function for Slack Notifications
module "lambda" {
  source = "./modules/lambda"

  function_name       = "bedrock-cost-notifier"
  sns_topic_arn       = module.sns.topic_arn
  ssm_parameter_name  = module.ssm.parameter_name
  ssm_parameter_arn   = module.ssm.parameter_arn
  tags               = local.common_tags

  depends_on = [module.ssm, module.sns]
}

# AWS Budget for Bedrock Service
module "budgets" {
  source = "./modules/budgets"

  budget_name         = "bedrock-monthly-budget"
  budget_amount       = var.budget_amount
  budget_start_date   = var.budget_start_date
  sns_topic_arn       = module.sns.topic_arn
  notification_email  = var.notification_email
  tags               = local.common_tags

  depends_on = [module.sns]
}
