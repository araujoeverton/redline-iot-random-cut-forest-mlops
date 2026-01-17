# IoT Certificates Directory

This directory stores X.509 certificates for AWS IoT Core authentication.

⚠️ **CRITICAL SECURITY**: Never commit certificates or private keys to git!

## Files Expected

For each vehicle (e.g., GT3-RACER-01):

```
simulator/certs/
├── GT3-RACER-01.cert.pem        # Public certificate
├── GT3-RACER-01.private.key     # Private key (KEEP SECURE!)
├── AmazonRootCA1.pem            # AWS Root CA certificate
└── README.md                    # This file
```

## Setup Instructions

### Step 1: Deploy Infrastructure

```bash
cd terraform
terraform apply -var-file=environments/dev/terraform.tfvars
```

### Step 2: Extract Certificates from Terraform

```bash
# Save certificates to JSON files (temporary)
terraform output -json iot_certificate_pems > /tmp/certs.json
terraform output -json iot_certificate_private_keys > /tmp/keys.json

# Extract for each vehicle
cd ../simulator/certs

# For GT3-RACER-01
jq -r '.["GT3-RACER-01"]' /tmp/certs.json > GT3-RACER-01.cert.pem
jq -r '.["GT3-RACER-01"]' /tmp/keys.json > GT3-RACER-01.private.key

# Download Amazon Root CA 1
curl https://www.amazontrust.com/repository/AmazonRootCA1.pem -o AmazonRootCA1.pem

# Secure the private key
chmod 600 *.private.key
chmod 644 *.cert.pem *.pem

# Clean up temporary files
rm /tmp/certs.json /tmp/keys.json
```

### Step 3: Verify Certificates

```bash
# Check certificate details
openssl x509 -in GT3-RACER-01.cert.pem -text -noout

# Verify private key matches certificate
openssl x509 -noout -modulus -in GT3-RACER-01.cert.pem | openssl md5
openssl rsa -noout -modulus -in GT3-RACER-01.private.key | openssl md5
# Both MD5 hashes should match
```

## Certificate Lifecycle

### Rotation Schedule
- **Recommended**: Every 90 days
- **Maximum**: 365 days
- **Set Calendar Reminder**: 80 days after creation

### Rotation Process

1. **Create New Certificate**:
   ```bash
   cd terraform
   terraform apply -var="create_certificates=true"
   ```

2. **Extract New Certificates** (follow Step 2 above)

3. **Update Simulator Config**:
   ```yaml
   # config/default.yml
   iot:
     cert_path: "./certs/GT3-RACER-01-NEW.cert.pem"
     private_key_path: "./certs/GT3-RACER-01-NEW.private.key"
   ```

4. **Test New Certificate**:
   ```bash
   python src/main.py --config config/default.yml --duration 60
   ```

5. **Deactivate Old Certificate**:
   ```bash
   aws iot update-certificate \
     --certificate-id OLD_CERT_ID \
     --new-status INACTIVE
   ```

6. **Delete Old Certificate** (after 30 days):
   ```bash
   # Detach from policy
   aws iot detach-policy \
     --policy-name redline-vehicle-telemetry-dev \
     --target OLD_CERT_ARN

   # Detach from thing
   aws iot detach-thing-principal \
     --thing-name GT3-RACER-01 \
     --principal OLD_CERT_ARN

   # Delete
   aws iot delete-certificate \
     --certificate-id OLD_CERT_ID
   ```

## Security Best Practices

### File Permissions

```bash
# Private keys: Read-only by owner
chmod 600 *.private.key

# Certificates: Readable by all
chmod 644 *.cert.pem *.pem
```

### Storage

- ✅ **DO**: Store in this directory (gitignored)
- ✅ **DO**: Back up to AWS Secrets Manager or 1Password
- ❌ **DON'T**: Commit to git
- ❌ **DON'T**: Share via email or Slack
- ❌ **DON'T**: Store in cloud drives without encryption

### Backup to AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name redline/iot/GT3-RACER-01/certificate \
  --secret-string file://GT3-RACER-01.cert.pem

aws secretsmanager create-secret \
  --name redline/iot/GT3-RACER-01/private-key \
  --secret-string file://GT3-RACER-01.private.key
```

## Troubleshooting

### Error: "Not Authorized to Connect"

**Cause**: Certificate not activated or not attached to Thing

**Solution**:
```bash
# Activate certificate
aws iot update-certificate \
  --certificate-id CERT_ID \
  --new-status ACTIVE

# Attach to Thing
aws iot attach-thing-principal \
  --thing-name GT3-RACER-01 \
  --principal CERT_ARN

# Attach to Policy
aws iot attach-policy \
  --policy-name redline-vehicle-telemetry-dev \
  --target CERT_ARN
```

### Error: "TLS Handshake Failed"

**Cause**: Wrong Root CA or certificate mismatch

**Solution**:
```bash
# Re-download Root CA
curl https://www.amazontrust.com/repository/AmazonRootCA1.pem -o AmazonRootCA1.pem

# Verify certificate integrity
openssl verify -CAfile AmazonRootCA1.pem GT3-RACER-01.cert.pem
```

### Error: "File Not Found"

**Cause**: Incorrect path in simulator config

**Solution**: Use absolute paths or paths relative to simulator directory
```yaml
iot:
  cert_path: "./certs/GT3-RACER-01.cert.pem"
  # NOT: "../simulator/certs/..." or "/absolute/path/..."
```

## Certificate Information

### Amazon Root CA 1
- **Valid Until**: 2038
- **SHA-256 Fingerprint**: `69:79:87:38:15:77:50:68:5F:08:61:AE:46:F9:8E:93...`
- **Download**: https://www.amazontrust.com/repository/AmazonRootCA1.pem

### Your Certificates
After setup, check certificate expiration:
```bash
openssl x509 -in GT3-RACER-01.cert.pem -noout -enddate
```

## Multi-Vehicle Setup

For multiple vehicles:

```bash
# Extract all certificates
for vehicle in GT3-RACER-01 GT3-RACER-02 GT3-RACER-03; do
  jq -r ".[\"$vehicle\"]" /tmp/certs.json > ${vehicle}.cert.pem
  jq -r ".[\"$vehicle\"]" /tmp/keys.json > ${vehicle}.private.key
  chmod 600 ${vehicle}.private.key
  chmod 644 ${vehicle}.cert.pem
done
```

## Support

For issues:
1. Check [terraform/modules/iot_core/README.md](../../terraform/modules/iot_core/README.md)
2. See [docs/runbooks/troubleshooting.md](../../docs/runbooks/troubleshooting.md)
3. Open GitHub issue with sanitized logs (no private keys!)
