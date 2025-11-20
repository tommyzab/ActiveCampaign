#!/bin/bash
set -e # Stop script immediately on first error

# Generate a unique name using timestamp to ensure uniqueness
UNIQUE_ID=$(date +%s)
BUCKET_NAME="okta-eks-state-$UNIQUE_ID"
TABLE_NAME="okta-eks-state-$UNIQUE_ID"
REGION="us-east-1"

echo "====== STARTING SETUP ======"
echo "1. Creating S3 Bucket: $BUCKET_NAME..."
# 'mb' (Make Bucket) handles region logic automatically
aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"

echo "2. Creating DynamoDB Table: $TABLE_NAME..."
aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
    --region "$REGION" > /dev/null
# (> /dev/null hides the massive JSON output if it succeeds)

echo "3. Generating backend.tf..."
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "global/s3/terraform.tfstate"
    region         = "$REGION"
    dynamodb_table = "$TABLE_NAME"
    encrypt        = true
  }
}
EOF

echo "====== VERIFICATION ======"
echo "Checking if resources exist..."
aws s3 ls | grep "$BUCKET_NAME"
aws dynamodb list-tables --region "$REGION" | grep "$TABLE_NAME"

echo "====== SUCCESS ======"
echo "Backend created! You must now run: terraform init"