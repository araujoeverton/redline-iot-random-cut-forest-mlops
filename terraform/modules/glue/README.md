# Glue Module - Data Catalog

This module creates AWS Glue resources for data cataloging and schema management.

## Resources Created

### 1. Glue Catalog Database
- **Name**: `redline_telemetry` (configurable)
- **Purpose**: Container for telemetry tables and metadata

### 2. Glue Catalog Table
- **Name**: `telemetry_raw`
- **Format**: Apache Parquet with Snappy compression
- **Partitioning**: `year/month/day/hour` for optimal query performance
- **Schema**: 18 columns (vehicle metadata + brake sensors + engine sensors)

#### Table Schema

| Column | Type | Description |
|--------|------|-------------|
| `vehicle_id` | string | Unique vehicle identifier |
| `timestamp` | bigint | Unix timestamp (milliseconds) |
| `session_id` | string | Driving session identifier |
| **Brake Sensors** | | |
| `brake_disc_temp_fl` | double | Front-left disc temperature (°C) |
| `brake_disc_temp_fr` | double | Front-right disc temperature (°C) |
| `brake_disc_temp_rl` | double | Rear-left disc temperature (°C) |
| `brake_disc_temp_rr` | double | Rear-right disc temperature (°C) |
| `brake_fluid_pressure` | double | Brake fluid pressure (bar) |
| `brake_pad_wear_fl` | double | Front-left pad wear (% remaining) |
| `brake_pad_wear_fr` | double | Front-right pad wear (% remaining) |
| `brake_pad_wear_rl` | double | Rear-left pad wear (% remaining) |
| `brake_pad_wear_rr` | double | Rear-right pad wear (% remaining) |
| **Engine Sensors** | | |
| `engine_rpm` | int | Engine RPM |
| `engine_oil_temp` | double | Oil temperature (°C) |
| `engine_oil_pressure` | double | Oil pressure (bar) |
| `engine_coolant_temp` | double | Coolant temperature (°C) |
| `boost_pressure` | double | Turbo boost pressure (bar) |
| `fuel_consumption_rate` | double | Fuel consumption (L/100km) |
| `throttle_position` | double | Throttle position (0.0-1.0) |

### 3. Glue Crawler
- **Name**: `redline-telemetry-crawler-{environment}`
- **Schedule**: Hourly (configurable via cron expression, native Glue schedule)
- **Behavior**:
  - Crawls new folders only (cost optimization)
  - Auto-discovers new partitions
  - Logs schema changes (required for CRAWL_NEW_FOLDERS_ONLY)
  - Logs deleted partitions

### 4. CloudWatch Logs
- **Log Group**: `/aws-glue/crawlers/{crawler-name}`
- **Retention**: 30 days (dev), 90 days (prod)

## Partitioning Strategy

Data is partitioned by time for optimal query performance:

```
s3://redline-datalake-{account-id}-{region}/raw/telemetry/
├── year=2026/
│   ├── month=01/
│   │   ├── day=14/
│   │   │   ├── hour=22/
│   │   │   │   ├── telemetry-1-2026-01-14-22-00-12345.parquet
│   │   │   │   └── telemetry-1-2026-01-14-22-05-67890.parquet
```

### Query Examples

**Filter by date (partition pruning)**:
```sql
SELECT COUNT(*)
FROM redline_telemetry.telemetry_raw
WHERE year = 2026 AND month = 1 AND day = 14;
```

**Find brake fade events**:
```sql
SELECT vehicle_id, timestamp,
       brake_disc_temp_fl, brake_disc_temp_fr
FROM redline_telemetry.telemetry_raw
WHERE year = 2026 AND month = 1
  AND (brake_disc_temp_fl > 600 OR brake_disc_temp_fr > 600)
ORDER BY timestamp DESC;
```

## Schema Evolution

The crawler supports schema evolution:

1. **New Columns**: Automatically added to table
2. **Column Type Changes**: Logged and updated
3. **Deleted Columns**: Logged (not removed from table)

This allows the simulator to add new sensors without infrastructure changes.

## Usage

```hcl
module "glue" {
  source = "./modules/glue"

  environment        = "dev"
  project_name       = "redline"
  database_name      = "redline_telemetry"
  s3_bucket_name     = module.s3.bucket_name
  s3_bucket_arn      = module.s3.bucket_arn
  crawler_role_arn   = module.iam.glue_crawler_role_arn
  crawler_schedule   = "cron(0 * * * ? *)"  # Hourly

  tags = {
    Team = "data-engineering"
  }
}
```

## Cost Optimization

### Crawler Costs
- **Data scanned**: $1.00 per 100,000 objects
- **DPU-Hour**: $0.44 per DPU-Hour

**Estimated cost** (1 vehicle @ 10 Hz):
- Objects per hour: 1 Parquet file (~600 records)
- Objects per day: 24 files
- Monthly cost: 24 * 30 = 720 objects = $0.007/month

### Optimization Strategies
1. **Crawl new folders only**: Reduces scan time by 90%
2. **Hourly schedule**: Balance freshness vs. cost
3. **Partition pruning**: Athena queries scan only relevant partitions

## Athena Integration

After crawler runs, query data with Athena:

```bash
# Start query execution
aws athena start-query-execution \
  --query-string "SELECT * FROM redline_telemetry.telemetry_raw LIMIT 10" \
  --query-execution-context Database=redline_telemetry \
  --result-configuration OutputLocation=s3://redline-datalake-{account-id}-{region}/athena-results/
```

## Outputs

- `database_name`: For Athena queries
- `table_name`: For SageMaker data access
- `crawler_arn`: For monitoring and alarming
