# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MLOps project for high-performance vehicle telemetry (sports cars). The system ingests real-time sensor data, stores it in a Data Lake, and uses Machine Learning (Random Cut Forest / Isolation Forest) for anomaly detection (brake fading, oil pressure, etc.).

## Architecture

### Phase A: Ingestion and Storage (Cold Path)

**Data Flow:** IoT Device (Simulator) → AWS IoT Core → Kinesis Data Firehose → S3 Data Lake

**AWS IoT Core:**
- Thing Name: `GT3-RACER-01`
- Topic Pattern: `car/+/telemetry` (wildcard `+` = vehicle_id)
- Authentication: X.509 Certificates (Cert.pem, Private.key, RootCA)
- Certificate Location: `./simulator/certs/`

**Kinesis Data Firehose:**
- Delivery Stream: `redline-telemetry-delivery-stream`
- Source: Direct PUT (via IoT Rule)
- Transformation: JSON → Apache Parquet
- Buffering: 128 MB or 300 seconds

**S3 Data Lake:**
- Bucket: `redline-datalake-{account-id}-{region}`

## Project Structure

### Terraform Infrastructure
- Organized as modules in separate directories named after AWS resources
- `environments/` directory contains `terraform.tfvars` for environment-specific configuration
- All infrastructure must be provisioned via Terraform

### Python Telemetry Simulator
- Located in `./simulator/`
- Runs locally and publishes to AWS IoT Core
- Uses certificates from `./simulator/certs/`

## Common Commands

### Terraform
```bash
# Initialize Terraform
terraform init

# Plan infrastructure changes
terraform plan -var-file=environments/terraform.tfvars

# Apply infrastructure
terraform apply -var-file=environments/terraform.tfvars

# Destroy infrastructure
terraform destroy -var-file=environments/terraform.tfvars
```

### Python Simulator
```bash
# Run telemetry simulator
python simulator/main.py

# Install dependencies (when requirements.txt exists)
pip install -r simulator/requirements.txt
```

## Important Constraints

- All AWS infrastructure must be defined in Terraform modules
- Telemetry data format: JSON input, Parquet output (for cost and query optimization)
- Certificate-based authentication required for IoT Core
- Data Lake naming convention: `redline-datalake-{account-id}-{region}`