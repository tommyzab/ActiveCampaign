#!/bin/bash
set -e # Stop on error

# --- CONFIGURATION (MUST MATCH setup.sh) ---
PROJECT_PREFIX="tommy-okta-assignment" 
AWS_REGION="us-east-1"
# ---------------------------------

BUCKET_NAME="${PROJECT_PREFIX}-tf-state"
TABLE_NAME="${PROJECT_PREFIX}-tf-locks"

echo "====== CLEANING UP TERRAFORM BACKEND ======"

# 1. Delete S3 Bucket (must be empty first)
echo "1. Deleting S3 Bucket: $BUCKET_NAME..."
if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "   -> Bucket doesn't exist. Skipping."
else
    echo "   -> Emptying bucket first..."
    aws s3 rm "s3://$BUCKET_NAME" --recursive 2>/dev/null || echo "   -> Bucket already empty or error (continuing)..."
    echo "   -> Deleting bucket..."
    aws s3 rb "s3://$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null || echo "   -> Error deleting bucket (may not exist or have objects)"
    echo "   -> Bucket deleted."
fi

# 2. Delete DynamoDB Table
echo "2. Deleting DynamoDB Table: $TABLE_NAME..."
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" 2>/dev/null | grep -q 'TableName'; then
    aws dynamodb delete-table \
        --table-name "$TABLE_NAME" \
        --region "$AWS_REGION" 2>/dev/null || echo "   -> Error deleting table (may not exist)"
    echo "   -> Waiting for table deletion..."
    aws dynamodb wait table-not-exists --table-name "$TABLE_NAME" --region "$AWS_REGION" 2>/dev/null || true
    echo "   -> Table deleted."
else
    echo "   -> Table doesn't exist. Skipping."
fi

# 3. Delete local Terraform files
echo "3. Cleaning up local Terraform files..."
cd "$(dirname "$0")/.."  # Go to project root

if [ -f "backend.tf" ]; then
    rm -f backend.tf
    echo "   -> Deleted backend.tf"
else
    echo "   -> backend.tf doesn't exist. Skipping."
fi

if [ -d ".terraform" ]; then
    rm -rf .terraform
    echo "   -> Deleted .terraform/ directory"
else
    echo "   -> .terraform/ doesn't exist. Skipping."
fi

if [ -f ".terraform.lock.hcl" ]; then
    rm -f .terraform.lock.hcl
    echo "   -> Deleted .terraform.lock.hcl"
else
    echo "   -> .terraform.lock.hcl doesn't exist. Skipping."
fi

echo "====== CLEANUP COMPLETE ======"
echo "All backend resources and local Terraform files have been removed."
echo "Run './bootstrap/setup.sh' to recreate the backend when ready."

