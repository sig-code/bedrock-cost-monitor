# Terraform State Management
#
# For production environments, it's recommended to use S3 backend with DynamoDB locking
# Uncomment and configure the following block:
#
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "bedrock-cost-monitor/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }
#
# For development/testing, local backend is used by default (no configuration needed)
