# ============================================================================
# Redline IoT Telemetry - Main Terraform Configuration
# ============================================================================

# Local variables for resource naming
locals {
  name_prefix          = "${var.project_name}-${var.environment}"
  firehose_stream_name = "${local.name_prefix}-telemetry-delivery-stream"
  glue_database_name   = "${var.project_name}_telemetry"

  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  })
}

# ============================================================================
# Module: S3 Data Lake
# ============================================================================

module "s3" {
  source = "./modules/s3"

  environment                  = var.environment
  project_name                 = var.project_name
  lifecycle_raw_glacier_days   = var.s3_lifecycle_raw_days
  lifecycle_raw_delete_days    = var.s3_lifecycle_glacier_days
  lifecycle_errors_delete_days = 7
  lifecycle_debug_delete_days  = 1
  enable_versioning            = true

  tags = local.common_tags
}

# ============================================================================
# Module: IAM Roles and Policies
# ============================================================================

module "iam" {
  source = "./modules/iam"

  environment          = var.environment
  project_name         = var.project_name
  firehose_stream_name = local.firehose_stream_name
  s3_bucket_arn        = module.s3.bucket_arn
  kms_key_arn          = module.s3.kms_key_arn
  glue_database_name   = local.glue_database_name

  tags = local.common_tags

  depends_on = [module.s3]
}

# ============================================================================
# Module: AWS Glue Catalog
# ============================================================================

module "glue" {
  source = "./modules/glue"

  environment      = var.environment
  project_name     = var.project_name
  database_name    = local.glue_database_name
  s3_bucket_name   = module.s3.bucket_name
  s3_bucket_arn    = module.s3.bucket_arn
  crawler_role_arn = module.iam.glue_crawler_role_arn

  tags = local.common_tags

  depends_on = [module.s3, module.iam]
}

# ============================================================================
# Module: Kinesis Firehose
# ============================================================================

module "kinesis_firehose" {
  source = "./modules/kinesis_firehose"

  environment               = var.environment
  project_name              = var.project_name
  stream_name               = local.firehose_stream_name
  s3_bucket_arn             = module.s3.bucket_arn
  s3_bucket_name            = module.s3.bucket_name
  buffering_size_mb         = var.firehose_buffering_size_mb
  buffering_interval_sec    = var.firehose_buffering_interval_sec
  enable_parquet_conversion = var.enable_parquet_conversion
  glue_database_name        = module.glue.database_name
  glue_table_name           = module.glue.table_name
  firehose_role_arn         = module.iam.firehose_to_s3_role_arn
  kms_key_arn               = module.s3.kms_key_arn

  tags = local.common_tags

  depends_on = [module.s3, module.iam, module.glue]
}

# ============================================================================
# Module: AWS IoT Core
# ============================================================================

module "iot_core" {
  source = "./modules/iot_core"

  environment         = var.environment
  project_name        = var.project_name
  vehicle_ids         = var.vehicle_ids
  firehose_stream_arn = module.kinesis_firehose.stream_arn
  iot_role_arn        = module.iam.iot_to_firehose_role_arn

  tags = local.common_tags

  depends_on = [module.kinesis_firehose, module.iam]
}

# ============================================================================
# Module: SageMaker Studio Domain
# ============================================================================

module "sagemaker" {
  source = "./modules/sagemaker"

  environment                    = var.environment
  project_name                   = var.project_name
  s3_bucket_name                 = module.s3.bucket_name
  sagemaker_execution_role_arn   = module.iam.sagemaker_execution_role_arn
  default_instance_type          = var.sagemaker_default_instance_type
  user_profile_name              = var.sagemaker_user_profile_name

  tags = local.common_tags

  depends_on = [module.s3, module.iam]
}

# ============================================================================
# Module: CloudWatch Observability (Commented until module is created)
# ============================================================================

# module "cloudwatch" {
#   source = "./modules/cloudwatch"
#
#   environment              = var.environment
#   project_name             = var.project_name
#   firehose_stream_name     = local.firehose_stream_name
#   s3_bucket_name           = module.s3.bucket_name
#   enable_alarms            = var.enable_cloudwatch_alarms
#   alarm_email              = var.alarm_email
#
#   tags = local.common_tags
#
#   depends_on = [module.kinesis_firehose, module.s3]
# }
