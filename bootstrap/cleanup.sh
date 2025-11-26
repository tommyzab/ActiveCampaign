#!/bin/bash
set -e # Stop script immediately on first error

REGION="us-east-1"

# Change to project root directory
cd "$(dirname "$0")/.."

echo "====== CLEANING UP TERRAFORM BACKEND ======"

# Read bucket and table names from backend.tf (if it exists)
if [ -f "backend.tf" ]; then
    # Use sed for macOS compatibility (BSD sed, works on both macOS and Linux)
    BUCKET_NAME=$(grep 'bucket' backend.tf | sed -n 's/.*bucket[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    TABLE_NAME=$(grep 'dynamodb_table' backend.tf | sed -n 's/.*dynamodb_table[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    REGION=$(grep 'region' backend.tf | sed -n 's/.*region[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    
    if [ -z "$BUCKET_NAME" ] || [ -z "$TABLE_NAME" ]; then
        echo "ERROR: Could not extract bucket or table name from backend.tf"
        echo "Please check backend.tf or specify names manually."
        exit 1
    fi
    
    echo "Found resources from backend.tf:"
    echo "  Bucket: $BUCKET_NAME"
    echo "  Table: $TABLE_NAME"
    echo "  Region: $REGION"
else
    echo "ERROR: backend.tf not found."
    echo "Cannot determine which resources to delete."
    echo "If you know the bucket/table names, you can delete them manually:"
    echo "  aws s3 rb s3://BUCKET_NAME --force"
    echo "  aws dynamodb delete-table --table-name TABLE_NAME --region $REGION"
    exit 1
fi

# 1. Delete S3 Bucket (must be empty first)
echo ""
echo "1. Deleting S3 Bucket: $BUCKET_NAME..."
if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "   -> Bucket doesn't exist. Skipping."
else
    echo "   -> Emptying bucket first..."
    aws s3 rm "s3://$BUCKET_NAME" --recursive 2>/dev/null || echo "   -> Bucket already empty or error (continuing)..."
    echo "   -> Deleting bucket..."
    aws s3 rb "s3://$BUCKET_NAME" --region "$REGION" 2>/dev/null || echo "   -> Error deleting bucket (may not exist or have objects)"
    echo "   -> Bucket deleted."
fi

# 2. Delete DynamoDB Table
echo ""
echo "2. Deleting DynamoDB Table: $TABLE_NAME..."
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" 2>/dev/null | grep -q 'TableName'; then
    aws dynamodb delete-table \
        --table-name "$TABLE_NAME" \
        --region "$REGION" 2>/dev/null || echo "   -> Error deleting table (may not exist)"
    echo "   -> Waiting for table deletion..."
    aws dynamodb wait table-not-exists --table-name "$TABLE_NAME" --region "$REGION" 2>/dev/null || true
    echo "   -> Table deleted."
else
    echo "   -> Table doesn't exist. Skipping."
fi

# 3. Delete local Terraform files
echo ""
echo "3. Cleaning up local Terraform files..."

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

if [ -f "errored.tfstate" ]; then
    rm -f errored.tfstate
    echo "   -> Deleted errored.tfstate"
else
    echo "   -> errored.tfstate doesn't exist. Skipping."
fi

# 4. Delete EC2 Key Pair (created by setup.sh, not managed by Terraform)
echo ""
echo "4. Deleting EC2 Key Pair..."
KEYPAIR_NAME="okta-eks-nodes-keypair"
if aws ec2 describe-key-pairs --key-names "$KEYPAIR_NAME" --region "$REGION" 2>/dev/null | grep -q "$KEYPAIR_NAME"; then
    aws ec2 delete-key-pair \
        --key-name "$KEYPAIR_NAME" \
        --region "$REGION" 2>/dev/null || echo "   -> Error deleting key pair (may not exist or in use)"
    echo "   -> Key pair deleted."
else
    echo "   -> Key pair doesn't exist. Skipping."
fi

# 5. Delete local keypair file and helper script
echo ""
echo "5. Cleaning up local helper files..."

if [ -f "${KEYPAIR_NAME}.pem" ]; then
    rm -f "${KEYPAIR_NAME}.pem"
    echo "   -> Deleted ${KEYPAIR_NAME}.pem"
else
    echo "   -> ${KEYPAIR_NAME}.pem doesn't exist. Skipping."
fi

if [ -f "get-cluster-sg.sh" ]; then
    rm -f get-cluster-sg.sh
    echo "   -> Deleted get-cluster-sg.sh"
else
    echo "   -> get-cluster-sg.sh doesn't exist. Skipping."
fi

echo ""
echo "====== CLEANUP COMPLETE ======"
echo "All backend resources, EC2 keypair, and local files have been removed."
echo ""
echo "Note: If you ran 'terraform destroy' first, all Terraform-managed resources"
echo "      (EKS cluster, security groups, etc.) have also been destroyed."
echo ""
echo "Run './bootstrap/setup.sh' to recreate the backend when ready."

