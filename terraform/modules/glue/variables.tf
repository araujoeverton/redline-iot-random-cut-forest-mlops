variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "database_name" {
  description = "Name of the Glue catalog database"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 Data Lake bucket"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 Data Lake bucket"
  type        = string
}

variable "crawler_role_arn" {
  description = "ARN of IAM role for Glue Crawler"
  type        = string
}

variable "crawler_schedule" {
  description = "Cron expression for crawler schedule"
  type        = string
  default     = "cron(0 * * * ? *)" # Hourly
}

variable "tags" {
  description = "Tags to apply to Glue resources"
  type        = map(string)
  default     = {}
}
