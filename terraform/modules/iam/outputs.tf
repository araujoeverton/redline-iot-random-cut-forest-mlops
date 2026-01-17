output "iot_to_firehose_role_arn" {
  description = "ARN of IAM role for IoT Core to Kinesis Firehose"
  value       = aws_iam_role.iot_to_firehose.arn
}

output "iot_to_firehose_role_name" {
  description = "Name of IAM role for IoT Core to Kinesis Firehose"
  value       = aws_iam_role.iot_to_firehose.name
}

output "firehose_to_s3_role_arn" {
  description = "ARN of IAM role for Kinesis Firehose to S3"
  value       = aws_iam_role.firehose_to_s3.arn
}

output "firehose_to_s3_role_name" {
  description = "Name of IAM role for Kinesis Firehose to S3"
  value       = aws_iam_role.firehose_to_s3.name
}

output "glue_crawler_role_arn" {
  description = "ARN of IAM role for Glue Crawler"
  value       = aws_iam_role.glue_crawler.arn
}

output "glue_crawler_role_name" {
  description = "Name of IAM role for Glue Crawler"
  value       = aws_iam_role.glue_crawler.name
}
