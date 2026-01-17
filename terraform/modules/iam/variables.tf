variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "firehose_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 Data Lake bucket"
  type        = string
}

variable "glue_database_name" {
  description = "Name of the Glue catalog database"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  type        = string
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
