output "bucket_name" {
  description = "Name of the Data Lake S3 bucket"
  value       = aws_s3_bucket.datalake.id
}

output "bucket_arn" {
  description = "ARN of the Data Lake S3 bucket"
  value       = aws_s3_bucket.datalake.arn
}

output "bucket_domain_name" {
  description = "Domain name of the Data Lake S3 bucket"
  value       = aws_s3_bucket.datalake.bucket_domain_name
}

output "kms_key_id" {
  description = "ID of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3.arn
}

output "logs_bucket_name" {
  description = "Name of the S3 access logs bucket"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "ARN of the S3 access logs bucket"
  value       = aws_s3_bucket.logs.arn
}
