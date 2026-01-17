# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# KMS Key for S3 Encryption
# ============================================================================

resource "aws_kms_key" "s3" {
  description             = "KMS key for ${var.project_name} Data Lake encryption (${var.environment})"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Firehose Service Roles to use the key"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "s3.${data.aws_region.current.name}.amazonaws.com",
              "firehose.${data.aws_region.current.name}.amazonaws.com"
            ]
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-s3-kms-${var.environment}"
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project_name}-s3-${var.environment}"
  target_key_id = aws_kms_key.s3.key_id
}

# ============================================================================
# S3 Data Lake Bucket
# ============================================================================

resource "aws_s3_bucket" "datalake" {
  bucket = "${var.project_name}-datalake-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-datalake-${var.environment}"
  })
}

# Versioning
resource "aws_s3_bucket_versioning" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policies
resource "aws_s3_bucket_lifecycle_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  # Raw telemetry data: Standard -> Glacier -> Delete
  rule {
    id     = "raw-telemetry-lifecycle"
    status = "Enabled"

    filter {
      prefix = "raw/telemetry/"
    }

    transition {
      days          = var.lifecycle_raw_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.lifecycle_raw_glacier_days + var.lifecycle_raw_delete_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # Error logs: Delete after 7 days
  rule {
    id     = "errors-lifecycle"
    status = "Enabled"

    filter {
      prefix = "errors/"
    }

    expiration {
      days = var.lifecycle_errors_delete_days
    }
  }

  # Debug JSON: Delete after 1 day
  rule {
    id     = "debug-lifecycle"
    status = "Enabled"

    filter {
      prefix = "debug/"
    }

    expiration {
      days = var.lifecycle_debug_delete_days
    }
  }

  # Processed data: Keep longer
  rule {
    id     = "processed-lifecycle"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 730
    }
  }
}

# Bucket policy to enforce encryption
resource "aws_s3_bucket_policy" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.datalake.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.datalake.arn,
          "${aws_s3_bucket.datalake.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ============================================================================
# S3 Bucket Logging (Optional - for audit trail)
# ============================================================================

resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-logs-${var.environment}"
  })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_logging" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "datalake-access-logs/"
}
