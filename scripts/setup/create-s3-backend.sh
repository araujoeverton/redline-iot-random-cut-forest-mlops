#!/bin/bash
#
# Script to create Terraform S3 backend infrastructure
# This should be run ONCE before first terraform init
#

set -e

# Configuration
PROJECT_NAME="redline"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ACCOUNT_ID}"
DYNAMODB_TABLE="${PROJECT_NAME}-terraform-locks"
KMS_ALIAS="alias/terraform-state"

echo "========================================="
echo "Creating Terraform Backend Infrastructure"
echo "========================================="
echo "Region: ${AWS_REGION}"
echo "Account ID: ${ACCOUNT_ID}"
echo "Bucket: ${BUCKET_NAME}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "========================================="
echo ""

# Create KMS key for state encryption
echo "[1/5] Creating KMS key for Terraform state encryption..."
KMS_KEY_ID=$(aws kms create-key \
  --description "KMS key for Terraform state encryption" \
  --region ${AWS_REGION} \
  --query 'KeyMetadata.KeyId' \
  --output text)

echo "KMS Key ID: ${KMS_KEY_ID}"

# Create KMS alias
echo "[2/5] Creating KMS alias..."
aws kms create-alias \
  --alias-name ${KMS_ALIAS} \
  --target-key-id ${KMS_KEY_ID} \
  --region ${AWS_REGION}

# Enable key rotation
echo "[3/5] Enabling automatic key rotation..."
aws kms enable-key-rotation \
  --key-id ${KMS_KEY_ID} \
  --region ${AWS_REGION}

# Create S3 bucket for state
echo "[4/5] Creating S3 bucket for Terraform state..."
aws s3api create-bucket \
  --bucket ${BUCKET_NAME} \
  --region ${AWS_REGION} \
  $(if [ "${AWS_REGION}" != "us-east-1" ]; then echo "--create-bucket-configuration LocationConstraint=${AWS_REGION}"; fi)

# Enable versioning
echo "Enabling bucket versioning..."
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled \
  --region ${AWS_REGION}

# Enable encryption
echo "Enabling bucket encryption..."
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "'"${KMS_KEY_ID}"'"
      },
      "BucketKeyEnabled": true
    }]
  }' \
  --region ${AWS_REGION}

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region ${AWS_REGION}

# Create DynamoDB table for state locking
echo "[5/5] Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --table-name ${DYNAMODB_TABLE} \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${AWS_REGION} \
  --tags Key=Project,Value=${PROJECT_NAME} Key=ManagedBy,Value=script

echo ""
echo "========================================="
echo "Backend Infrastructure Created!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Update terraform/environments/*/backend.tf with:"
echo "   bucket         = \"${BUCKET_NAME}\""
echo "   dynamodb_table = \"${DYNAMODB_TABLE}\""
echo "   kms_key_id     = \"${KMS_ALIAS}\""
echo ""
echo "2. Run: terraform init"
echo "========================================="
