variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "stream_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 Data Lake bucket"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 Data Lake bucket"
  type        = string
}

variable "buffering_size_mb" {
  description = "Buffer size in MB before flushing to S3"
  type        = number
  default     = 128
}

variable "buffering_interval_sec" {
  description = "Buffer interval in seconds before flushing to S3"
  type        = number
  default     = 300
}

variable "enable_parquet_conversion" {
  description = "Enable JSON to Parquet conversion"
  type        = bool
  default     = true
}

variable "glue_database_name" {
  description = "Name of the Glue catalog database"
  type        = string
}

variable "glue_table_name" {
  description = "Name of the Glue catalog table"
  type        = string
}

variable "firehose_role_arn" {
  description = "ARN of IAM role for Firehose"
  type        = string
}

variable "compression_format" {
  description = "Compression format for Parquet (SNAPPY, GZIP, UNCOMPRESSED)"
  type        = string
  default     = "SNAPPY"
}

variable "tags" {
  description = "Tags to apply to Firehose resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of KMS key for S3 encryption"
  type        = string
}
