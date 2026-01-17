# Redline IoT Random Cut Forest MLOps

Professional event-driven telemetry architecture for high-performance vehicle monitoring with ML-based anomaly detection.

## Overview

This project implements an enterprise-grade MLOps pipeline for real-time telemetry ingestion from sports cars, featuring:

- **Event-Driven Architecture**: AWS IoT Core → Kinesis Firehose → S3 Data Lake
- **Real-time Ingestion**: 10 Hz sensor sampling with sub-second latency
- **Cost-Optimized Storage**: JSON → Parquet transformation (70-80% reduction)
- **Anomaly Detection**: AWS SageMaker Random Cut Forest (brake fading, engine overheat)
- **Full Observability**: CloudWatch Logs, Metrics, Dashboards, and Alarms
- **Infrastructure as Code**: 100% Terraform with modular design
- **CI/CD**: GitHub Actions workflows for validation and deployment

## Architecture

```
┌─────────────┐    MQTT/TLS    ┌──────────────┐    Direct PUT    ┌─────────────────┐
│  Simulator  │───────────────>│ AWS IoT Core │─────────────────>│ Kinesis         │
│  (Python)   │   QoS 1        │  (X.509 auth)│   IoT Rule       │ Firehose        │
└─────────────┘                └──────────────┘                  └────────┬────────┘
                                                                           │
                                                                           │ Transform
                                                                           │ JSON→Parquet
                                                                           │
                                                                           v
┌──────────────┐                ┌──────────────┐                  ┌───────────────┐
│  Athena /    │<───────────────│  Glue        │<─────────────────│  S3 Data Lake │
│  SageMaker   │   Query        │  Catalog     │   Crawler        │  (Encrypted)  │
└──────────────┘                └──────────────┘                  └───────────────┘
```

## Project Structure

```
redline-iot-random-cut-forest-mlops/
├── terraform/                  # Infrastructure as Code
│   ├── modules/                # Reusable Terraform modules
│   │   ├── iam/                # IAM roles and policies
│   │   ├── s3/                 # Data Lake with lifecycle policies
│   │   ├── iot_core/           # IoT Things, policies, topic rules
│   │   ├── kinesis_firehose/   # Streaming data delivery
│   │   ├── glue/               # Data catalog and crawlers
│   │   └── cloudwatch/         # Observability (logs, metrics, alarms)
│   ├── environments/           # Environment-specific configs
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── main.tf                 # Root module orchestration
│   ├── variables.tf            # Global variables
│   └── outputs.tf              # Global outputs
│
├── simulator/                  # Python telemetry simulator
│   ├── src/
│   │   ├── telemetry/sensors/  # Physics-based sensor models
│   │   ├── iot/                # MQTT publisher with retry logic
│   │   ├── config/             # Configuration management
│   │   └── observability/      # Logging and metrics
│   ├── config/                 # YAML configurations
│   ├── certs/                  # X.509 certificates (gitignored)
│   └── tests/                  # Unit and integration tests
│
├── docs/                       # Documentation
│   ├── architecture/           # C4 diagrams and data flows
│   ├── adr/                    # Architecture Decision Records
│   └── runbooks/               # Operational procedures
│
├── scripts/                    # Automation scripts
│   ├── setup/                  # Infrastructure bootstrap
│   └── deploy/                 # Deployment wrappers
│
└── .github/workflows/          # CI/CD pipelines
```

## Quick Start

### Prerequisites

- **AWS CLI**: Configured with appropriate credentials
- **Terraform**: >= 1.6.0
- **Python**: >= 3.11
- **Git**: For version control

### 1. Create Terraform Backend

```bash
# Create S3 bucket and DynamoDB table for Terraform state
./scripts/setup/create-s3-backend.sh

# Update backend configuration with output values
# Edit terraform/environments/dev/backend.tf
```

### 2. Deploy Infrastructure (Dev)

```bash
cd terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan -var-file=environments/dev/terraform.tfvars

# Deploy infrastructure
terraform apply -var-file=environments/dev/terraform.tfvars
```

### 3. Run Simulator (Coming Soon)

```bash
cd simulator

# Install dependencies
pip install -r requirements.txt

# Configure IoT endpoint and certificates
# Edit config/default.yml with outputs from terraform apply

# Run telemetry simulator
python src/main.py --config config/default.yml
```

## Key Features

### 1. Physics-Based Telemetry Simulation

The simulator generates realistic sensor data using physics models:

- **Brake System**:
  - Friction heating: Q = μ × F × v
  - Newton's cooling law
  - Brake fade anomaly injection (> 600°C)

- **Engine System**:
  - RPM distribution (idle/cruise/race modes)
  - Oil temperature with thermal dissipation
  - Boost pressure (turbo model)

### 2. Security

- **Encryption at Rest**: KMS customer-managed keys
- **Encryption in Transit**: TLS 1.3 for IoT, HTTPS for S3
- **Authentication**: X.509 certificates for devices
- **IAM**: Least privilege roles with resource scoping
- **Public Access**: Completely blocked on S3

### 3. Cost Optimization

| Service | Monthly Cost (1 vehicle @ 10Hz) |
|---------|----------------------------------|
| IoT Core | $3.60 |
| Kinesis Firehose | $0.05 |
| S3 Standard | $0.12 |
| S3 Glacier | $0.26 |
| CloudWatch | $16.00 |
| **Total** | **~$20/month** |

**Optimization strategies**:
- Parquet conversion (70-80% storage reduction)
- Lifecycle policies (Standard → Glacier → Delete)
- S3 Bucket Keys (99% reduction in KMS costs)

### 4. Observability

- **Logs**: Structured JSON logs in CloudWatch
- **Metrics**: Custom metrics for pipeline health
- **Dashboards**: Real-time telemetry ingestion monitoring
- **Alarms**: 8 critical alarms (delivery failures, latency, errors)

## Development Workflow

### Terraform Changes

```bash
# Format code
terraform fmt -recursive

# Validate
terraform validate

# Plan with environment
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply
terraform apply -var-file=environments/dev/terraform.tfvars
```

### Python Development

```bash
# Install dev dependencies
pip install -r simulator/requirements-dev.txt

# Format code
black simulator/

# Type check
mypy simulator/src/ --strict

# Run tests
pytest simulator/tests/
```

## Documentation

- **Architecture**: [docs/architecture/](docs/architecture/) - C4 diagrams and data flow
- **ADRs**: [docs/adr/](docs/adr/) - Architecture decisions and trade-offs
- **Runbooks**: [docs/runbooks/](docs/runbooks/) - Operational procedures
- **Modules**: Each Terraform module has its own README

## Roadmap

### Phase A: Ingestion & Storage (Current)
- [x] Terraform infrastructure modules (IAM, S3)
- [ ] IoT Core, Kinesis Firehose, Glue modules
- [ ] Python simulator with physics models
- [ ] CloudWatch observability
- [ ] CI/CD pipelines

### Phase B: Hot Path (Future)
- [ ] Kinesis Data Streams for real-time processing
- [ ] Lambda functions for instant anomaly detection
- [ ] DynamoDB for hot storage

### Phase C: ML Pipeline (Future)
- [ ] SageMaker Random Cut Forest training
- [ ] Model deployment and inference
- [ ] A/B testing framework

### Phase D: Production Scale (Future)
- [ ] Multi-region deployment
- [ ] Auto-scaling (1000+ vehicles)
- [ ] Cost attribution per vehicle

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

Copyright © 2026 Redline Telemetry. All rights reserved.

## Support

For issues and questions:
- **GitHub Issues**: [Create an issue](https://github.com/araujoeverton/redline-iot-random-cut-forest-mlops/issues)
- **Documentation**: See [docs/](docs/) directory
