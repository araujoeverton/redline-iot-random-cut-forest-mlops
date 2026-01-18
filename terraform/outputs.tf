output "s3_bucket_name" {
  description = "Name of the Data Lake S3 bucket"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the Data Lake S3 bucket"
  value       = module.s3.bucket_arn
}

output "iot_endpoint" {
  description = "AWS IoT Core endpoint"
  value       = module.iot_core.iot_endpoint
}

output "iot_thing_arns" {
  description = "ARNs of IoT Things"
  value       = module.iot_core.thing_arns
}

output "firehose_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  value       = module.kinesis_firehose.stream_name
}

output "firehose_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream"
  value       = module.kinesis_firehose.stream_arn
}

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = module.glue.database_name
}

output "glue_table_name" {
  description = "Name of the Glue catalog table"
  value       = module.glue.table_name
}

# CloudWatch module not yet implemented
# output "cloudwatch_dashboard_url" {
#   description = "URL to CloudWatch dashboard"
#   value       = module.cloudwatch.dashboard_url
# }

output "iam_role_iot_to_firehose_arn" {
  description = "ARN of IAM role for IoT to Firehose"
  value       = module.iam.iot_to_firehose_role_arn
}

output "iam_role_firehose_to_s3_arn" {
  description = "ARN of IAM role for Firehose to S3"
  value       = module.iam.firehose_to_s3_role_arn
}

# Additional IoT Core outputs for simulator configuration
output "iot_certificate_pems" {
  description = "Certificate PEMs (save to files immediately)"
  value       = module.iot_core.certificate_pems
  sensitive   = true
}

output "iot_certificate_private_keys" {
  description = "Private keys (save to files immediately and keep secure)"
  value       = module.iot_core.certificate_private_keys
  sensitive   = true
}

output "mqtt_topic_pattern" {
  description = "MQTT topic pattern for publishing telemetry"
  value       = module.iot_core.mqtt_topic_pattern
}

output "iot_thing_names" {
  description = "Names of IoT Things created"
  value       = module.iot_core.thing_names
}

# ============================================================================
# SageMaker Studio Outputs
# ============================================================================

output "sagemaker_domain_id" {
  description = "SageMaker Studio Domain ID"
  value       = module.sagemaker.domain_id
}

output "sagemaker_domain_arn" {
  description = "SageMaker Studio Domain ARN"
  value       = module.sagemaker.domain_arn
}

output "sagemaker_domain_url" {
  description = "SageMaker Studio Domain URL"
  value       = module.sagemaker.domain_url
}

output "sagemaker_user_profile_name" {
  description = "SageMaker Studio User Profile Name"
  value       = module.sagemaker.user_profile_name
}

output "sagemaker_execution_role_arn" {
  description = "ARN of IAM role for SageMaker execution"
  value       = module.iam.sagemaker_execution_role_arn
}
