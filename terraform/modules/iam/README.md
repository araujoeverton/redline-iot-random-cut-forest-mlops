# IAM Module

This module creates all IAM roles and policies required for the Redline IoT telemetry pipeline.

## Resources Created

### 1. IoT Core to Kinesis Firehose Role
- **Role**: `redline-iot-to-firehose-{environment}`
- **Trust**: iot.amazonaws.com
- **Permissions**:
  - `firehose:PutRecord`
  - `firehose:PutRecordBatch`
- **Scope**: Specific Firehose delivery stream

### 2. Kinesis Firehose to S3 Role
- **Role**: `redline-firehose-to-s3-{environment}`
- **Trust**: firehose.amazonaws.com (with ExternalId condition)
- **Permissions**:
  - S3: Get, Put, List operations
  - Glue: Get table/version operations
  - CloudWatch Logs: Write logs
- **Scope**: Specific S3 bucket and Glue database

### 3. Glue Crawler Role
- **Role**: `redline-glue-crawler-{environment}`
- **Trust**: glue.amazonaws.com
- **Permissions**:
  - S3: Read/Write in raw/ prefix
  - Glue: Create/Update tables and partitions
  - CloudWatch Logs: Write logs
- **Managed Policy**: AWSGlueServiceRole

## Security Features

- **Least Privilege**: All roles have minimal required permissions
- **Resource Scoping**: No wildcard ARNs in production
- **Condition Keys**: ExternalId for Firehose role
- **Explicit Deny**: No public access permissions

## Usage

```hcl
module "iam" {
  source = "./modules/iam"

  environment          = "dev"
  project_name         = "redline"
  firehose_stream_name = "redline-telemetry-delivery-stream"
  s3_bucket_arn        = "arn:aws:s3:::redline-datalake-123456789012-us-east-1"
  glue_database_name   = "redline_telemetry"

  tags = {
    Team = "data-engineering"
  }
}
```

## Outputs

- `iot_to_firehose_role_arn`: ARN for IoT Topic Rule
- `firehose_to_s3_role_arn`: ARN for Firehose delivery stream
- `glue_crawler_role_arn`: ARN for Glue Crawler configuration
