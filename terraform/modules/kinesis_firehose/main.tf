# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ============================================================================
# CloudWatch Log Group for Firehose
# ============================================================================

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.stream_name}"
  retention_in_days = var.environment == "prod" ? 90 : 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-firehose-logs-${var.environment}"
  })
}

resource "aws_cloudwatch_log_stream" "firehose_delivery" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

resource "aws_cloudwatch_log_stream" "firehose_backup" {
  name           = "BackupDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

# ============================================================================
# Kinesis Firehose Delivery Stream
# ============================================================================

resource "aws_kinesis_firehose_delivery_stream" "telemetry" {
  name        = var.stream_name
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = var.firehose_role_arn
    bucket_arn          = var.s3_bucket_arn
    prefix              = "raw/telemetry/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/!{firehose:error-output-type}/"

    buffering_size     = var.buffering_size_mb
    buffering_interval = var.buffering_interval_sec
    compression_format = var.enable_parquet_conversion ? "UNCOMPRESSED" : "GZIP"

    # S3 Encryption with KMS
    kms_key_arn = var.kms_key_arn

    # Data format conversion (JSON → Parquet)
    dynamic "data_format_conversion_configuration" {
      for_each = var.enable_parquet_conversion ? [1] : []

      content {
        input_format_configuration {
          deserializer {
            open_x_json_ser_de {}
          }
        }

        output_format_configuration {
          serializer {
            parquet_ser_de {
              compression                   = var.compression_format
              block_size_bytes              = 268435456 # 256 MB
              page_size_bytes               = 1048576   # 1 MB
              enable_dictionary_compression = true
              writer_version                = "V2"
            }
          }
        }

        schema_configuration {
          database_name = var.glue_database_name
          table_name    = var.glue_table_name
          region        = data.aws_region.current.name
          role_arn      = var.firehose_role_arn
        }
      }
    }

    # CloudWatch Logging
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_delivery.name
    }

    # S3 Backup (for failed records only)
    s3_backup_mode = "Enabled"

    s3_backup_configuration {
      role_arn            = var.firehose_role_arn
      bucket_arn          = var.s3_bucket_arn
      prefix              = "debug/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
      error_output_prefix = "debug-errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/!{firehose:error-output-type}/"
      buffering_size      = 5
      buffering_interval  = 300
      compression_format  = "GZIP"

      cloudwatch_logging_options {
        enabled         = true
        log_group_name  = aws_cloudwatch_log_group.firehose.name
        log_stream_name = aws_cloudwatch_log_stream.firehose_backup.name
      }
    }
  }

  tags = merge(var.tags, {
    Name = var.stream_name
  })
}

# ============================================================================
# CloudWatch Metrics and Alarms
# ============================================================================

# Metric: Delivery Success
resource "aws_cloudwatch_metric_alarm" "delivery_success" {
  alarm_name          = "${var.stream_name}-delivery-success"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DeliveryToS3.Success"
  namespace           = "AWS/Firehose"
  period              = 300
  statistic           = "Average"
  threshold           = 0.95 # 95% success rate
  alarm_description   = "Firehose delivery success rate below 95%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DeliveryStreamName = aws_kinesis_firehose_delivery_stream.telemetry.name
  }

  tags = merge(var.tags, {
    Name     = "${var.stream_name}-delivery-success-alarm"
    Severity = "high"
  })
}

# Metric: Data Freshness (latency)
resource "aws_cloudwatch_metric_alarm" "data_freshness" {
  alarm_name          = "${var.stream_name}-data-freshness"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DeliveryToS3.DataFreshness"
  namespace           = "AWS/Firehose"
  period              = 300
  statistic           = "Maximum"
  threshold           = 600 # 10 minutes
  alarm_description   = "Firehose data freshness exceeds 10 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DeliveryStreamName = aws_kinesis_firehose_delivery_stream.telemetry.name
  }

  tags = merge(var.tags, {
    Name     = "${var.stream_name}-data-freshness-alarm"
    Severity = "medium"
  })
}

# Metric: Incoming Records
resource "aws_cloudwatch_metric_alarm" "no_incoming_records" {
  alarm_name          = "${var.stream_name}-no-incoming-records"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "IncomingRecords"
  namespace           = "AWS/Firehose"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "No records received by Firehose for 15 minutes"
  treat_missing_data  = "breaching"

  dimensions = {
    DeliveryStreamName = aws_kinesis_firehose_delivery_stream.telemetry.name
  }

  tags = merge(var.tags, {
    Name     = "${var.stream_name}-no-incoming-records-alarm"
    Severity = "medium"
  })
}
