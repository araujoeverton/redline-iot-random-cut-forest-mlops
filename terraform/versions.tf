terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration (will be configured per environment)
  # backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "redline-iot-rcf-mlops"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "data-engineering"
    }
  }
}
