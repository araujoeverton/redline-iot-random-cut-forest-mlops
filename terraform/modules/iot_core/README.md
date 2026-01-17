# IoT Core Module

This module creates AWS IoT Core resources for secure device connectivity and message routing.

## Resources Created

### 1. IoT Things
- **Purpose**: Virtual representation of physical vehicles
- **Count**: One per vehicle_id in var.vehicle_ids
- **Attributes**: environment, project, vehicle_type

### 2. X.509 Certificates
- **Type**: AWS-generated certificates
- **Lifecycle**: Active immediately
- **Components**:
  - Certificate PEM
  - Private Key (RSA 2048-bit)
  - Public Key
  - CA Certificate (Amazon Root CA 1)

**CRITICAL**: Private keys are only available during creation. They must be saved immediately!

### 3. IoT Policy (Least Privilege)
- **Name**: `redline-vehicle-telemetry-{environment}`
- **Permissions**:
  - ✅ **ALLOW**: `iot:Connect` (only with attached certificate)
  - ✅ **ALLOW**: `iot:Publish` to `car/{thing_name}/telemetry`
  - ❌ **DENY**: `iot:Subscribe`, `iot:Receive` (no subscriptions)

**Security Features**:
- Client ID must match Thing Name
- Certificate must be attached to Thing
- Publish only to own telemetry topic
- No wildcards in allowed topics

### 4. IoT Topic Rule
- **Name**: `redline_telemetry_to_firehose_{environment}`
- **SQL**: `SELECT *, topic(2) as vehicle_id, timestamp() as timestamp FROM 'car/+/telemetry'`
- **Action**: Forward to Kinesis Firehose
- **Error Handling**: Log to CloudWatch

#### Topic Rule Features
- **Wildcard Matching**: `+` matches any vehicle_id
- **Data Enrichment**:
  - Extracts vehicle_id from topic (topic(2))
  - Adds server-side timestamp
- **Separator**: Newline (`\n`) for NDJSON format

### 5. CloudWatch Monitoring

#### Log Groups
- `/aws/iot/rules/{rule-name}/errors` - Rule execution errors
- `/aws/iot/rules/{rule-name}/actions` - Successful action invocations

#### Alarms
1. **Topic Rule Errors**: Triggers on throttling or errors (>10 in 5 min)
2. **No Messages**: Triggers if no messages received for 15 minutes

## MQTT Topic Structure

### Publishing from Simulator
```
Topic: car/GT3-RACER-01/telemetry
QoS: 1 (At Least Once)
Format: JSON
```

### Message Flow
```
Simulator → car/{vehicle_id}/telemetry → IoT Topic Rule → Kinesis Firehose → S3
```

## Certificate Management

### Initial Setup (After Terraform Apply)

```bash
# 1. Extract certificates from Terraform state
terraform output -json iot_core_certificate_pems > certs.json

# 2. Save to files (per vehicle)
jq -r '.["GT3-RACER-01"]' certs.json > simulator/certs/GT3-RACER-01.cert.pem
terraform output -json iot_core_certificate_private_keys | jq -r '.["GT3-RACER-01"]' > simulator/certs/GT3-RACER-01.private.key

# 3. Download Amazon Root CA 1
curl https://www.amazontrust.com/repository/AmazonRootCA1.pem -o simulator/certs/AmazonRootCA1.pem

# 4. Set secure permissions
chmod 600 simulator/certs/*.key
chmod 644 simulator/certs/*.pem
```

### Certificate Rotation

**Rotation Policy**: Every 90 days (recommended)

```bash
# 1. Create new certificate (Terraform)
terraform apply -var="create_certificates=true"

# 2. Update simulator config with new cert paths

# 3. Test new certificate

# 4. Deactivate old certificate
aws iot update-certificate --certificate-id OLD_CERT_ID --new-status INACTIVE

# 5. Delete old certificate (after 30 days)
aws iot delete-certificate --certificate-id OLD_CERT_ID
```

## Security Best Practices

### 1. Least Privilege Policy
```json
{
  "Effect": "Allow",
  "Action": "iot:Publish",
  "Resource": "arn:aws:iot:region:account:topic/car/${iot:Connection.Thing.ThingName}/telemetry"
}
```

**Why**: Device can only publish to its own topic, not other vehicles' topics.

### 2. Certificate Binding
```json
{
  "Condition": {
    "Bool": {
      "iot:Connection.Thing.IsAttached": "true"
    }
  }
}
```

**Why**: Certificate must be attached to Thing (prevents stolen cert reuse).

### 3. No Subscriptions
```json
{
  "Effect": "Deny",
  "Action": ["iot:Subscribe", "iot:Receive"],
  "Resource": "*"
}
```

**Why**: Telemetry devices don't need to receive messages (attack surface reduction).

### 4. TLS 1.3
All MQTT connections use TLS 1.3 with mutual authentication (mTLS).

## Testing

### 1. Test MQTT Connection
```bash
# Using mosquitto_pub
mosquitto_pub \
  --cafile simulator/certs/AmazonRootCA1.pem \
  --cert simulator/certs/GT3-RACER-01.cert.pem \
  --key simulator/certs/GT3-RACER-01.private.key \
  -h a1b2c3d4e5f6g7-ats.iot.us-east-1.amazonaws.com \
  -p 8883 \
  -t car/GT3-RACER-01/telemetry \
  -m '{"vehicle_id":"GT3-RACER-01","timestamp":1705267200000,"engine_rpm":3500}'
```

### 2. Monitor Topic Rule
```bash
# Check CloudWatch Logs
aws logs tail /aws/iot/rules/redline_telemetry_to_firehose_dev/actions --follow
```

### 3. Verify Firehose Delivery
```bash
# Check Firehose metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Firehose \
  --metric-name IncomingRecords \
  --dimensions Name=DeliveryStreamName,Value=redline-telemetry-delivery-stream-dev \
  --start-time 2026-01-14T00:00:00Z \
  --end-time 2026-01-14T23:59:59Z \
  --period 300 \
  --statistics Sum
```

## Troubleshooting

### Problem: "Not Authorized to Connect"
**Cause**: Certificate not attached or policy incorrect
**Solution**:
```bash
aws iot attach-thing-principal \
  --thing-name GT3-RACER-01 \
  --principal arn:aws:iot:region:account:cert/CERT_ID

aws iot attach-policy \
  --policy-name redline-vehicle-telemetry-dev \
  --target arn:aws:iot:region:account:cert/CERT_ID
```

### Problem: "Not Authorized to Publish"
**Cause**: Topic doesn't match policy pattern
**Solution**: Verify topic is `car/{thing_name}/telemetry`

### Problem: "Messages Not Reaching Firehose"
**Cause**: Topic Rule SQL or IAM role issue
**Solution**:
```bash
# Check rule logs
aws logs tail /aws/iot/rules/redline_telemetry_to_firehose_dev/errors --follow

# Test rule manually
aws iot test-invoke-authorizer --custom-authorizer-name redline_telemetry_to_firehose_dev
```

## Usage

```hcl
module "iot_core" {
  source = "./modules/iot_core"

  environment          = "dev"
  project_name         = "redline"
  vehicle_ids          = ["GT3-RACER-01", "GT3-RACER-02"]
  firehose_stream_arn  = module.kinesis_firehose.stream_arn
  iot_role_arn         = module.iam.iot_to_firehose_role_arn
  topic_pattern        = "car/+/telemetry"
  create_certificates  = true

  tags = {
    Team = "data-engineering"
  }
}
```

## Outputs

**Non-Sensitive**:
- `iot_endpoint` - MQTT broker endpoint (use in simulator config)
- `thing_names` - List of Thing names created
- `topic_rule_name` - For monitoring dashboards

**Sensitive** (save immediately):
- `certificate_pems` - Public certificates
- `certificate_private_keys` - **CRITICAL**: Save to secure storage immediately
- `certificate_public_keys` - Public keys for verification

## Cost

| Resource | Monthly Cost |
|----------|--------------|
| IoT Things | Free (first 50) |
| MQTT Messages | $1.00 per 1M messages |
| Topic Rules | $0.15 per 1M actions |
| **Total (1 vehicle @ 10Hz)** | **$3.60/month** |

**Calculation**: 10 msg/sec * 2.6M sec/month = 26M messages = $3.60
