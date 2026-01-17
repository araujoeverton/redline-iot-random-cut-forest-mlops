output "iot_endpoint" {
  description = "AWS IoT Core data endpoint (ATS)"
  value       = data.aws_iot_endpoint.current.endpoint_address
}

output "thing_names" {
  description = "Names of IoT Things created"
  value       = [for thing in aws_iot_thing.vehicle : thing.name]
}

output "thing_arns" {
  description = "ARNs of IoT Things created"
  value       = { for k, thing in aws_iot_thing.vehicle : k => thing.arn }
}

output "certificate_arns" {
  description = "ARNs of X.509 certificates (sensitive)"
  value       = { for k, cert in aws_iot_certificate.vehicle : k => cert.arn }
  sensitive   = true
}

output "certificate_pems" {
  description = "PEM-encoded certificates (sensitive - save to files)"
  value       = { for k, cert in aws_iot_certificate.vehicle : k => cert.certificate_pem }
  sensitive   = true
}

output "certificate_private_keys" {
  description = "Private keys for certificates (sensitive - save to files immediately)"
  value       = { for k, cert in aws_iot_certificate.vehicle : k => cert.private_key }
  sensitive   = true
}

output "certificate_public_keys" {
  description = "Public keys for certificates"
  value       = { for k, cert in aws_iot_certificate.vehicle : k => cert.public_key }
  sensitive   = true
}

output "topic_rule_name" {
  description = "Name of the IoT Topic Rule"
  value       = aws_iot_topic_rule.telemetry_to_firehose.name
}

output "topic_rule_arn" {
  description = "ARN of the IoT Topic Rule"
  value       = aws_iot_topic_rule.telemetry_to_firehose.arn
}

output "iot_policy_name" {
  description = "Name of the IoT Policy"
  value       = aws_iot_policy.vehicle_telemetry.name
}

output "iot_policy_arn" {
  description = "ARN of the IoT Policy"
  value       = aws_iot_policy.vehicle_telemetry.arn
}

output "topic_rule_errors_log_group" {
  description = "CloudWatch log group for IoT Rule errors"
  value       = aws_cloudwatch_log_group.iot_rule_errors.name
}

output "mqtt_topic_pattern" {
  description = "MQTT topic pattern for publishing telemetry"
  value       = "car/{vehicle_id}/telemetry"
}
