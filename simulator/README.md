# Redline Telemetry Simulator

Python-based telemetry simulator for high-performance vehicle monitoring with realistic physics models.

## Features

- **Physics-Based Sensors**: Realistic brake and engine thermodynamics
- **AWS IoT Integration**: Secure MQTT publishing with X.509 certificates
- **Anomaly Injection**: Automatic brake fade and overheating events
- **Retry Logic**: Exponential backoff for network resilience
- **Structured Logging**: JSON logs for observability

## Prerequisites

- Python 3.11+
- AWS IoT Core infrastructure (deployed via Terraform)
- X.509 certificates (extracted from Terraform outputs)

## Installation

```bash
cd simulator

# Install dependencies
pip install -r requirements.txt

# For development
pip install -r requirements-dev.txt
```

## Setup

### 1. Extract Certificates from Terraform

```bash
cd ../terraform

# Get IoT endpoint
terraform output iot_endpoint

# Extract certificates
terraform output -json iot_certificate_pems | jq -r '.["GT3-RACER-01"]' > ../simulator/certs/GT3-RACER-01.cert.pem
terraform output -json iot_certificate_private_keys | jq -r '.["GT3-RACER-01"]' > ../simulator/certs/GT3-RACER-01.private.key

# Download Root CA
curl https://www.amazontrust.com/repository/AmazonRootCA1.pem -o ../simulator/certs/AmazonRootCA1.pem

# Secure permissions
chmod 600 ../simulator/certs/*.key
chmod 644 ../simulator/certs/*.pem
```

### 2. Configure Simulator

Edit `config/default.yml`:

```yaml
iot:
  endpoint: "a1b2c3d4e5f6g7-ats.iot.us-east-1.amazonaws.com"  # From terraform output
```

## Usage

### Basic Usage

```bash
python src/main.py --config config/default.yml
```

### Options

```bash
# Run for 5 minutes
python src/main.py --config config/default.yml --duration 300

# Use custom config
python src/main.py --config config/my-vehicle.yml
```

## Physics Models

### Brake Sensor

**Heat Generation:**
```
Q = μ * F * v
```

**Cooling (Newton's Law):**
```
dT/dt = -k * (T - T_ambient)
```

**Brake Fade:**
```
μ_effective = μ_nominal * exp(-fade_coeff * T)
```

**Anomaly**: Temperature spike > 600°C (10% probability)

### Engine Sensor

**Driving Modes:**
- **Idle** (10%): 800 RPM, 0% throttle
- **Cruise** (60%): 3500 RPM, 20-40% throttle
- **Race** (30%): 7500 RPM, 70-100% throttle

**Oil Temperature:**
- Heating: Proportional to RPM
- Cooling: Proportional to (T - T_nominal)

**Oil Pressure:**
```
P = k * RPM * (1 - temp_penalty)
```

**Anomaly**: Coolant leak causing rapid temperature rise (2% probability)

## Telemetry Schema

```json
{
  "vehicle_id": "GT3-RACER-01",
  "timestamp": 1705267200000,
  "session_id": "abc-123-def-456",
  "brake_disc_temp_fl": 652.3,
  "brake_disc_temp_fr": 648.1,
  "brake_disc_temp_rl": 320.5,
  "brake_disc_temp_rr": 318.2,
  "brake_fluid_pressure": 95.4,
  "brake_pad_wear_fl": 87.2,
  "brake_pad_wear_fr": 86.8,
  "brake_pad_wear_rl": 90.1,
  "brake_pad_wear_rr": 89.7,
  "engine_rpm": 7850,
  "engine_oil_temp": 105.2,
  "engine_oil_pressure": 4.8,
  "engine_coolant_temp": 99.9,
  "boost_pressure": 1.6,
  "fuel_consumption_rate": 18.5,
  "throttle_position": 0.92
}
```

## Development

### Code Quality

```bash
# Format code
black src/

# Type check
mypy src/ --strict

# Lint
pylint src/

# Security scan
bandit -r src/
```

### Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=html

# Run specific test
pytest tests/unit/test_brake_sensor.py
```

## Troubleshooting

### Connection Errors

**Problem**: `Not Authorized to Connect`

**Solution**:
1. Verify certificate paths in `config/default.yml`
2. Check certificate is active: `aws iot list-certificates`
3. Verify thing attachment: `aws iot list-thing-principals --thing-name GT3-RACER-01`

### Publishing Errors

**Problem**: `Not Authorized to Publish`

**Solution**:
1. Topic must match: `car/{thing_name}/telemetry`
2. Check IoT policy: `aws iot get-policy --policy-name redline-vehicle-telemetry-dev`

### Certificate Errors

**Problem**: `TLS Handshake Failed`

**Solution**:
1. Verify Root CA: `openssl verify -CAfile certs/AmazonRootCA1.pem certs/GT3-RACER-01.cert.pem`
2. Re-download Root CA if needed

## Architecture

```
┌─────────────────────┐
│  TelemetryGenerator │
│   ┌──────────────┐  │
│   │ BrakeSensor  │  │
│   └──────────────┘  │
│   ┌──────────────┐  │
│   │ EngineSensor │  │
│   └──────────────┘  │
└──────────┬──────────┘
           │ Generate sample
           v
┌─────────────────────┐
│   IoTPublisher      │
│  ┌───────────────┐  │
│  │ ExponentialBa│  │
│  │ ckoff Retry   │  │
│  └───────────────┘  │
└──────────┬──────────┘
           │ MQTT/TLS
           │ QoS: 1
           v
  ┌─────────────────┐
  │  AWS IoT Core   │
  │  (Topic Rule)   │
  └─────────────────┘
```

## Configuration

See [config/default.yml](config/default.yml) for all options:

- `vehicle`: Vehicle ID, duration, sample rate
- `iot`: IoT Core endpoint, certificates, topic
- `brake`: Brake physics parameters
- `engine`: Engine characteristics

## Performance

**Throughput**: 10 messages/second per vehicle
**Latency**: < 100ms (P99)
**Reliability**: 99.9% delivery (with retries)

## Support

- Documentation: [../docs/](../docs/)
- Terraform Modules: [../terraform/modules/iot_core/](../terraform/modules/iot_core/)
- Issues: GitHub Issues
