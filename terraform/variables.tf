variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "redline"
}

variable "vehicle_ids" {
  description = "List of vehicle IDs to provision"
  type        = list(string)
  default     = ["GT3-RACER-01"]
}

variable "firehose_buffering_size_mb" {
  description = "Firehose buffer size in MB"
  type        = number
  default     = 128

  validation {
    condition     = var.firehose_buffering_size_mb >= 1 && var.firehose_buffering_size_mb <= 128
    error_message = "Buffer size must be between 1 and 128 MB."
  }
}

variable "firehose_buffering_interval_sec" {
  description = "Firehose buffer interval in seconds"
  type        = number
  default     = 300

  validation {
    condition     = var.firehose_buffering_interval_sec >= 60 && var.firehose_buffering_interval_sec <= 900
    error_message = "Buffer interval must be between 60 and 900 seconds."
  }
}

variable "enable_parquet_conversion" {
  description = "Enable JSON to Parquet conversion in Firehose"
  type        = bool
  default     = true
}

variable "s3_lifecycle_raw_days" {
  description = "Days to keep raw data in S3 Standard before moving to Glacier"
  type        = number
  default     = 90
}

variable "s3_lifecycle_glacier_days" {
  description = "Days to keep data in Glacier before deletion"
  type        = number
  default     = 365
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
