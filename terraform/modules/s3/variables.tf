variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "lifecycle_raw_glacier_days" {
  description = "Days before moving raw data to Glacier"
  type        = number
  default     = 90
}

variable "lifecycle_raw_delete_days" {
  description = "Days before deleting data from Glacier"
  type        = number
  default     = 365
}

variable "lifecycle_errors_delete_days" {
  description = "Days before deleting error logs"
  type        = number
  default     = 7
}

variable "lifecycle_debug_delete_days" {
  description = "Days before deleting debug JSON data"
  type        = number
  default     = 1
}

variable "enable_versioning" {
  description = "Enable bucket versioning"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to S3 resources"
  type        = map(string)
  default     = {}
}
