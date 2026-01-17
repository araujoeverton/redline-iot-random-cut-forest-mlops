# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# AWS Glue Catalog Database
# ============================================================================

resource "aws_glue_catalog_database" "telemetry" {
  name        = var.database_name
  description = "Glue catalog database for ${var.project_name} telemetry data (${var.environment})"

  tags = merge(var.tags, {
    Name = var.database_name
  })
}

# ============================================================================
# AWS Glue Catalog Table - Telemetry Raw (Parquet)
# ============================================================================

resource "aws_glue_catalog_table" "telemetry_raw" {
  name          = "telemetry_raw"
  database_name = aws_glue_catalog_database.telemetry.name
  description   = "Raw telemetry data from vehicles (Parquet format)"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"  = "parquet"
    "compressionType" = "snappy"
    "typeOfData"      = "file"
    "EXTERNAL"        = "TRUE"
  }

  partition_keys {
    name = "year"
    type = "int"
  }

  partition_keys {
    name = "month"
    type = "int"
  }

  partition_keys {
    name = "day"
    type = "int"
  }

  partition_keys {
    name = "hour"
    type = "int"
  }

  storage_descriptor {
    location      = "s3://${var.s3_bucket_name}/raw/telemetry/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "ParquetHiveSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    # Schema for telemetry data
    columns {
      name = "vehicle_id"
      type = "string"
    }

    columns {
      name = "timestamp"
      type = "bigint"
    }

    columns {
      name = "session_id"
      type = "string"
    }

    # Brake sensors (4 wheels: FL, FR, RL, RR)
    columns {
      name = "brake_disc_temp_fl"
      type = "double"
    }

    columns {
      name = "brake_disc_temp_fr"
      type = "double"
    }

    columns {
      name = "brake_disc_temp_rl"
      type = "double"
    }

    columns {
      name = "brake_disc_temp_rr"
      type = "double"
    }

    columns {
      name = "brake_fluid_pressure"
      type = "double"
    }

    columns {
      name = "brake_pad_wear_fl"
      type = "double"
    }

    columns {
      name = "brake_pad_wear_fr"
      type = "double"
    }

    columns {
      name = "brake_pad_wear_rl"
      type = "double"
    }

    columns {
      name = "brake_pad_wear_rr"
      type = "double"
    }

    # Engine sensors
    columns {
      name = "engine_rpm"
      type = "int"
    }

    columns {
      name = "engine_oil_temp"
      type = "double"
    }

    columns {
      name = "engine_oil_pressure"
      type = "double"
    }

    columns {
      name = "engine_coolant_temp"
      type = "double"
    }

    columns {
      name = "boost_pressure"
      type = "double"
    }

    columns {
      name = "fuel_consumption_rate"
      type = "double"
    }

    columns {
      name = "throttle_position"
      type = "double"
    }
  }
}

# ============================================================================
# AWS Glue Crawler - Auto-discover schema and partitions
# ============================================================================

resource "aws_glue_crawler" "telemetry" {
  name          = "${var.project_name}-telemetry-crawler-${var.environment}"
  database_name = aws_glue_catalog_database.telemetry.name
  role          = var.crawler_role_arn
  description   = "Crawler for telemetry data partitions and schema evolution"

  # Native schedule (instead of EventBridge)
  schedule = var.crawler_schedule

  s3_target {
    path = "s3://${var.s3_bucket_name}/raw/telemetry/"
  }

  # Schema change policy (must be LOG/LOG for CRAWL_NEW_FOLDERS_ONLY)
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }

  # Recrawl policy (only new folders - cost optimization)
  recrawl_policy {
    recrawl_behavior = "CRAWL_NEW_FOLDERS_ONLY"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-telemetry-crawler-${var.environment}"
  })
}

# ============================================================================
# CloudWatch Log Group for Crawler
# ============================================================================

resource "aws_cloudwatch_log_group" "glue_crawler" {
  name              = "/aws-glue/crawlers/${aws_glue_crawler.telemetry.name}"
  retention_in_days = var.environment == "prod" ? 90 : 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-glue-crawler-logs-${var.environment}"
  })
}

