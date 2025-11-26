#!/bin/bash
set -e # Stop on error

# --- CONFIGURATION (EDIT THIS) ---
PROJECT_PREFIX="tommy-okta-assignment" 
AWS_REGION="us-east-1"
# ---------------------------------

BUCKET_NAME="${PROJECT_PREFIX}-tf-state"
TABLE_NAME="${PROJECT_PREFIX}-tf-locks"

echo "====== SETTING UP TERRAFORM BACKEND (NO VERSIONING) ======"

# 1. Create S3 Bucket
echo "1. Creating S3 Bucket: $BUCKET_NAME..."
if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION"
    echo "   -> Bucket created."
else
    echo "   -> Bucket already exists. Skipping creation."
fi

# 2. Enable Encryption (Free Security - AES256)
# Note: This uses standard S3 keys which are free.
echo "2. Enabling Bucket Encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

# 3. Create DynamoDB Table for Locking
echo "3. Creating/Checking DynamoDB Table: $TABLE_NAME..."
aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
    --region "$AWS_REGION" 2>/dev/null || echo "   -> Table likely already exists."

# 4. Generate the backend.tf file
echo "4. Generating backend.tf file..."
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "global/s3/terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "$TABLE_NAME"
    encrypt        = true
  }
}
EOF

echo "====== SUCCESS ======"
echo "Backend configured using bucket: $BUCKET_NAME"
echo "Note: Versioning is DISABLED."
echo "Run 'terraform init' to initialize."