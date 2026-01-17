# S3 Module - Data Lake

This module creates the S3 Data Lake infrastructure with security best practices and lifecycle policies.

## Resources Created

### 1. KMS Encryption
- **KMS Key**: Customer-managed key for S3 encryption
- **Key Rotation**: Enabled (automatic annual rotation)
- **Deletion Window**: 30 days

### 2. Data Lake Bucket
- **Naming**: `redline-datalake-{account-id}-{region}`
- **Versioning**: Enabled for data recovery
- **Encryption**: KMS (SSE-KMS) with bucket keys
- **Public Access**: Completely blocked

### 3. Bucket Structure
```
s3://redline-datalake-{account-id}-{region}/
├── raw/telemetry/          # Parquet files from Firehose
│   └── year=YYYY/month=MM/day=DD/hour=HH/
├── processed/              # ML-processed data
│   └── anomalies/
├── models/                 # SageMaker models
│   └── random-cut-forest/
├── errors/                 # Firehose delivery errors
└── debug/                  # 24h JSON retention for debugging
```

### 4. Lifecycle Policies

| Prefix | Standard Storage | Glacier | Delete |
|--------|-----------------|---------|--------|
| `raw/telemetry/` | 90 days | Yes | After 365 days in Glacier |
| `processed/` | 365 days | Yes | After 730 days total |
| `errors/` | 7 days | No | After 7 days |
| `debug/` | 1 day | No | After 1 day |

### 5. Security Features

#### Encryption
- **At Rest**: KMS encryption mandatory
- **In Transit**: HTTPS only (enforced by bucket policy)
- **Bucket Keys**: Enabled (reduces KMS costs by 99%)

#### Access Control
- **Public Access**: Blocked at bucket level
- **IAM Policies**: Least privilege via IAM module
- **Bucket Policy**: Denies unencrypted uploads and HTTP access

#### Audit
- **Access Logging**: Enabled to separate logs bucket
- **CloudTrail**: All S3 API calls logged (AWS-wide)
- **Versioning**: Protects against accidental deletion

## Usage

```hcl
module "s3" {
  source = "./modules/s3"

  environment                  = "dev"
  project_name                 = "redline"
  lifecycle_raw_glacier_days   = 90
  lifecycle_raw_delete_days    = 365
  lifecycle_errors_delete_days = 7
  lifecycle_debug_delete_days  = 1
  enable_versioning            = true

  tags = {
    CostCenter = "data-platform"
  }
}
```

## Cost Optimization

### Storage Tiers
- **Standard**: Hot data (0-90 days) - $0.023/GB/month
- **Glacier**: Cold data (90-455 days) - $0.004/GB/month
- **Delete**: After 455 days total

### Estimated Monthly Cost (1 vehicle, 10 Hz)
- Data ingested: 1.8 GB/month
- Standard storage (90 days): 5.4 GB = $0.12
- Glacier storage (12 months): 65 GB = $0.26
- **Total**: ~$0.40/month

### Bucket Keys
- Reduces KMS API calls by 99%
- Savings: ~$14/month for high-volume scenarios

## Outputs

- `bucket_name`: Use for Firehose destination
- `bucket_arn`: Use for IAM policies
- `kms_key_arn`: Use for cross-account access (if needed)
