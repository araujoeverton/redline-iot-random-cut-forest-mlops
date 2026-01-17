# Backend configuration for Dev environment
# Uncomment after creating S3 backend bucket via scripts/setup/create-s3-backend.sh

# terraform {
#   backend "s3" {
#     bucket         = "redline-terraform-state-ACCOUNT_ID"
#     key            = "dev/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "redline-terraform-locks"
#     kms_key_id     = "alias/terraform-state"
#   }
# }
