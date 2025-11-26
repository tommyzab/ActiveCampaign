#!/bin/bash
set -e # Stop script immediately on first error

REGION="us-east-1"

# Change to project root directory
cd "$(dirname "$0")/.."

echo "====== CLEANING UP TERRAFORM BACKEND ======"

# Read bucket and table names from backend.tf (if it exists)
BACKEND_EXISTS=false
if [ -f "backend.tf" ]; then
    # Use sed for macOS compatibility (BSD sed, works on both macOS and Linux)
    BUCKET_NAME=$(grep 'bucket' backend.tf | sed -n 's/.*bucket[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    TABLE_NAME=$(grep 'dynamodb_table' backend.tf | sed -n 's/.*dynamodb_table[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    BACKEND_REGION=$(grep 'region' backend.tf | sed -n 's/.*region[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    
    if [ -n "$BUCKET_NAME" ] && [ -n "$TABLE_NAME" ]; then
        BACKEND_EXISTS=true
        if [ -n "$BACKEND_REGION" ]; then
            REGION="$BACKEND_REGION"
        fi
        echo "Found resources from backend.tf:"
        echo "  Bucket: $BUCKET_NAME"
        echo "  Table: $TABLE_NAME"
        echo "  Region: $REGION"
    else
        echo "Warning: backend.tf exists but could not extract bucket/table names."
        echo "Skipping backend cleanup, but will continue with other cleanup tasks."
    fi
else
    echo "Note: backend.tf not found. Skipping S3/DynamoDB cleanup."
    echo "Will still clean up EC2 keypair and local files."
fi

# 1. Delete S3 Bucket (if backend.tf was found)
if [ "$BACKEND_EXISTS" = true ]; then
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
fi

# Clean up local Terraform files (always attempt, even if backend.tf missing)
STEP_NUM=$([ "$BACKEND_EXISTS" = true ] && echo "3" || echo "1")
echo ""
echo "${STEP_NUM}. Cleaning up local Terraform files..."

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

# Delete EC2 Key Pair (created by setup.sh, not managed by Terraform)
STEP_NUM=$([ "$BACKEND_EXISTS" = true ] && echo "4" || echo "2")
echo ""
echo "${STEP_NUM}. Deleting EC2 Key Pair..."
KEYPAIR_NAME="okta-eks-nodes-keypair"
if aws ec2 describe-key-pairs --key-names "$KEYPAIR_NAME" --region "$REGION" 2>/dev/null | grep -q "$KEYPAIR_NAME"; then
    aws ec2 delete-key-pair \
        --key-name "$KEYPAIR_NAME" \
        --region "$REGION" 2>/dev/null || echo "   -> Error deleting key pair (may not exist or in use)"
    echo "   -> Key pair deleted."
else
    echo "   -> Key pair doesn't exist. Skipping."
fi

# Delete Security Group (created by setup.sh, not managed by Terraform)
STEP_NUM=$([ "$BACKEND_EXISTS" = true ] && echo "5" || echo "3")
echo ""
echo "${STEP_NUM}. Deleting Security Group..."
SG_NAME="okta-eks-nodes-sg"
# Get default VPC ID
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --region "$REGION" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null)

if [ -n "$DEFAULT_VPC_ID" ] && [ "$DEFAULT_VPC_ID" != "None" ]; then
    NODE_SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$DEFAULT_VPC_ID" \
        --region "$REGION" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null)
    
    if [ -n "$NODE_SG_ID" ] && [ "$NODE_SG_ID" != "None" ]; then
        # Delete security group (will fail if still in use, which is expected)
        aws ec2 delete-security-group \
            --group-id "$NODE_SG_ID" \
            --region "$REGION" 2>/dev/null || echo "   -> Error deleting security group (may be in use by running instances)"
        echo "   -> Security group deleted."
    else
        echo "   -> Security group doesn't exist. Skipping."
    fi
else
    echo "   -> Could not find default VPC. Skipping security group deletion."
fi

# Delete local keypair file (keep helper script as it's useful)
STEP_NUM=$([ "$BACKEND_EXISTS" = true ] && echo "6" || echo "4")
echo ""
echo "${STEP_NUM}. Cleaning up local keypair file..."

if [ -f "${KEYPAIR_NAME}.pem" ]; then
    rm -f "${KEYPAIR_NAME}.pem"
    echo "   -> Deleted ${KEYPAIR_NAME}.pem"
else
    echo "   -> ${KEYPAIR_NAME}.pem doesn't exist. Skipping."
fi

# Note: get-cluster-sg.sh is kept as it's a useful helper script

echo ""
echo "====== CLEANUP COMPLETE ======"
echo "All backend resources, EC2 keypair, and local files have been removed."
echo ""
echo "Note: If you ran 'terraform destroy' first, all Terraform-managed resources"
echo "      (EKS cluster, security groups, etc.) have also been destroyed."
echo ""
echo "Run './bootstrap/setup.sh' to recreate the backend when ready."

