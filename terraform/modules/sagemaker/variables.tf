variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for SageMaker outputs"
  type        = string
}

variable "sagemaker_execution_role_arn" {
  description = "IAM role ARN for SageMaker execution"
  type        = string
}

variable "default_instance_type" {
  description = "Default instance type for SageMaker Studio Kernel Gateway (ml.t3.medium, ml.m5.large, etc.)"
  type        = string
  default     = "ml.t3.medium"
}

variable "user_profile_name" {
  description = "Name for the default SageMaker Studio user profile"
  type        = string
  default     = "data-scientist"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
