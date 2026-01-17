output "stream_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.telemetry.name
}

output "stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.telemetry.arn
}

output "stream_id" {
  description = "ID of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.telemetry.id
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.firehose.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.firehose.arn
}

output "delivery_success_alarm_arn" {
  description = "ARN of the delivery success alarm"
  value       = aws_cloudwatch_metric_alarm.delivery_success.arn
}

output "data_freshness_alarm_arn" {
  description = "ARN of the data freshness alarm"
  value       = aws_cloudwatch_metric_alarm.data_freshness.arn
}

output "no_incoming_records_alarm_arn" {
  description = "ARN of the no incoming records alarm"
  value       = aws_cloudwatch_metric_alarm.no_incoming_records.arn
}
