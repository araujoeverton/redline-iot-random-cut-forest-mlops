# Kinesis Firehose Module

This module creates Amazon Kinesis Data Firehose delivery stream for telemetry data ingestion with JSON to Parquet transformation.

## Resources Created

### 1. Kinesis Firehose Delivery Stream
- **Name**: `redline-telemetry-delivery-stream-{environment}`
- **Destination**: Extended S3 (with data transformation)
- **Buffering**: 128 MB or 300 seconds (configurable)
- **Transformation**: JSON → Parquet (optional)

### 2. Data Transformation Pipeline

```
IoT Rule → Firehose → [Buffer] → [Transform JSON→Parquet] → S3 (Partitioned)
                            ↓
                      [Failed Records]
                            ↓
                    S3 Backup (Debug)
```

#### Transformation Features
- **Input Format**: JSON (OpenX deserializer)
- **Output Format**: Apache Parquet
- **Compression**: Snappy (configurable)
- **Schema**: Glue Catalog reference
- **Block Size**: 256 MB (optimal for Athena)
- **Page Size**: 1 MB
- **Dictionary Compression**: Enabled

### 3. S3 Partitioning

**Primary Output** (Parquet):
```
s3://{bucket}/raw/telemetry/year=2026/month=01/day=14/hour=22/
```

**Error Output**:
```
s3://{bucket}/errors/year=2026/month=01/day=14/processing-failed/
```

**Debug Backup** (JSON - 24h retention):
```
s3://{bucket}/debug/year=2026/month=01/day=14/hour=22/
```

### 4. Buffering Strategy

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Size** | 128 MB | Optimal Parquet file size for Athena |
| **Interval** | 300s (5 min) | Balance latency vs. S3 PUT costs |
| **Backup Size** | 5 MB | Faster error detection |

**Cost Impact**:
- Smaller files → More S3 PUTs → Higher cost
- Larger files → Less frequent writes → Lower cost
- 128 MB @ 1.8 GB/month = ~14 files/month

### 5. CloudWatch Monitoring

#### Log Groups
- `/aws/kinesisfirehose/{stream-name}` - Delivery logs
  - **S3Delivery** stream - Primary delivery logs
  - **BackupDelivery** stream - Error backup logs

#### Metrics Collected
- `IncomingRecords` - Records received from IoT
- `IncomingBytes` - Data volume
- `DeliveryToS3.Success` - Successful deliveries
- `DeliveryToS3.DataFreshness` - End-to-end latency
- `DeliveryToS3.Records` - Records delivered
- `ExecuteProcessing.Duration` - Parquet conversion time

### 6. CloudWatch Alarms

#### 1. Delivery Success Alarm
- **Metric**: `DeliveryToS3.Success`
- **Threshold**: < 95%
- **Severity**: High
- **Action**: Indicates S3 access issues or IAM problems

#### 2. Data Freshness Alarm
- **Metric**: `DeliveryToS3.DataFreshness`
- **Threshold**: > 600 seconds (10 minutes)
- **Severity**: Medium
- **Action**: Indicates buffering delays or processing bottleneck

#### 3. No Incoming Records Alarm
- **Metric**: `IncomingRecords`
- **Threshold**: < 1 record in 15 minutes
- **Severity**: Medium
- **Action**: Indicates IoT Rule failure or device disconnection

## Data Format Conversion

### JSON Input Example
```json
{
  "vehicle_id": "GT3-RACER-01",
  "timestamp": 1705267200000,
  "session_id": "abc-123-def",
  "brake_disc_temp_fl": 652.3,
  "brake_disc_temp_fr": 648.1,
  "engine_rpm": 7850,
  "engine_oil_temp": 105.2
}
```

### Parquet Output
- **Compression**: Snappy (70-80% size reduction)
- **Columnar Storage**: Optimal for analytical queries
- **Schema**: Enforced by Glue Catalog
- **Partitions**: Hive-style (year/month/day/hour)

## Error Handling

### Failed Record Processing
1. **Parquet Conversion Errors**:
   - Logged to CloudWatch
   - Original JSON backed up to `errors/` prefix
   - Alarm triggered if rate > 5%

2. **S3 Access Denied**:
   - Check IAM role permissions
   - Verify bucket policy
   - Check KMS key policy

3. **Schema Mismatch**:
   - Glue Crawler updates schema
   - Firehose retries with new schema
   - Logged to CloudWatch

### Recovery Procedures
See [docs/runbooks/troubleshooting.md](../../../docs/runbooks/troubleshooting.md)

## Performance Characteristics

### Throughput
- **Max Throughput**: 1 MB/sec per shard (auto-scaling)
- **Current Load**: ~18 KB/sec (1 vehicle @ 10 Hz)
- **Headroom**: 98% capacity available

### Latency
- **Buffering**: 0-300 seconds
- **Transformation**: 10-30 seconds
- **S3 Upload**: 5-10 seconds
- **Total P99**: < 400 seconds (acceptable for cold path)

## Cost Analysis

### Monthly Cost (1 vehicle @ 10 Hz)

| Component | Usage | Cost |
|-----------|-------|------|
| Data ingested | 1.8 GB | $0.036 |
| Data format conversion | 1.8 GB | $0.018 |
| **Total Firehose** | | **$0.054/month** |

### Cost Breakdown
- **Ingestion**: $0.020 per GB ingested
- **Format Conversion**: $0.010 per GB converted
- **S3 PUTs**: Reduced by buffering (14 PUTs/month vs. 259,200)

## Usage

```hcl
module "kinesis_firehose" {
  source = "./modules/kinesis_firehose"

  environment                = "dev"
  project_name               = "redline"
  stream_name                = "redline-telemetry-delivery-stream-dev"
  s3_bucket_arn              = module.s3.bucket_arn
  s3_bucket_name             = module.s3.bucket_name
  buffering_size_mb          = 128
  buffering_interval_sec     = 300
  enable_parquet_conversion  = true
  glue_database_name         = module.glue.database_name
  glue_table_name            = module.glue.table_name
  firehose_role_arn          = module.iam.firehose_to_s3_role_arn
  compression_format         = "SNAPPY"

  tags = {
    Team = "data-engineering"
  }
}
```

## Testing

### 1. Manual Record Injection
```bash
# Send test record to Firehose
aws firehose put-record \
  --delivery-stream-name redline-telemetry-delivery-stream-dev \
  --record '{"Data":"eyJ2ZWhpY2xlX2lkIjoiVEVTVCJ9Cg=="}'
```

### 2. Verify S3 Delivery
```bash
# Check for new Parquet files
aws s3 ls s3://redline-datalake-{account-id}-{region}/raw/telemetry/ --recursive
```

### 3. Query with Athena
```sql
SELECT COUNT(*) FROM redline_telemetry.telemetry_raw
WHERE year = 2026 AND month = 1;
```

## Outputs

- `stream_arn`: For IoT Rule destination
- `stream_name`: For monitoring dashboards
- `log_group_name`: For troubleshooting
- `*_alarm_arn`: For SNS notification setup
