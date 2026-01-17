# Development Environment Configuration

environment  = "dev"
aws_region   = "us-east-1"
project_name = "redline"

# Vehicle Configuration
vehicle_ids = ["GT3-RACER-01"]

# Kinesis Firehose Configuration
firehose_buffering_size_mb      = 128
firehose_buffering_interval_sec = 300
enable_parquet_conversion       = true

# S3 Lifecycle Configuration
s3_lifecycle_raw_days     = 90
s3_lifecycle_glacier_days = 365

# Observability Configuration
enable_cloudwatch_alarms = true
alarm_email              = "" # Set your email for alarm notifications

# Additional Tags
tags = {
  Environment = "dev"
  Team        = "data-engineering"
  CostCenter  = "research-and-development"
  Project     = "redline-telemetry"
}
