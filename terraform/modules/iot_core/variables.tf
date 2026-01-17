variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "vehicle_ids" {
  description = "List of vehicle IDs to create IoT Things for"
  type        = list(string)
}

variable "firehose_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream"
  type        = string
}

variable "iot_role_arn" {
  description = "ARN of IAM role for IoT to Firehose"
  type        = string
}

variable "topic_pattern" {
  description = "MQTT topic pattern for telemetry"
  type        = string
  default     = "car/+/telemetry"
}

variable "create_certificates" {
  description = "Create X.509 certificates (disable if using existing certs)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to IoT resources"
  type        = map(string)
  default     = {}
}
