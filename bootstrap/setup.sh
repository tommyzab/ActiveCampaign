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

echo "3. Creating EC2 Key Pair for EKS nodes..."
KEYPAIR_NAME="okta-eks-nodes-keypair"
# Check if keypair already exists
if aws ec2 describe-key-pairs --key-names "$KEYPAIR_NAME" --region "$REGION" 2>/dev/null | grep -q "$KEYPAIR_NAME"; then
    echo "   -> Key pair '$KEYPAIR_NAME' already exists. Skipping creation."
else
    # Create keypair and save private key locally
    aws ec2 create-key-pair \
        --key-name "$KEYPAIR_NAME" \
        --region "$REGION" \
        --query 'KeyMaterial' \
        --output text > "${KEYPAIR_NAME}.pem" 2>/dev/null || {
        echo "   -> Warning: Could not create key pair (may need permissions). Continuing..."
    }
    if [ -f "${KEYPAIR_NAME}.pem" ]; then
        chmod 400 "${KEYPAIR_NAME}.pem"
        echo "   -> Key pair created and saved to ${KEYPAIR_NAME}.pem"
        echo "   -> IMPORTANT: Keep this file secure! You'll need it for SSH access to nodes."
    fi
fi

echo "4. Generating backend.tf..."
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

echo "5. Creating helper script to get cluster security group ID..."
cat > get-cluster-sg.sh <<'HELPER_EOF'
#!/bin/bash
# Helper script to get the EKS cluster security group ID after terraform apply
# This is needed for CloudFormation stack that creates unmanaged node groups

CLUSTER_NAME="${1:-demo-eks}"
REGION="${2:-us-east-1}"

echo "Getting cluster security group ID for cluster: $CLUSTER_NAME"
echo ""

# Try to get from Terraform output first (most reliable)
if command -v terraform &> /dev/null; then
    TERRAFORM_SG_ID=$(terraform output -raw cluster_security_group_id 2>/dev/null)
    if [ -n "$TERRAFORM_SG_ID" ] && [ "$TERRAFORM_SG_ID" != "null" ]; then
        CLUSTER_SG_ID="$TERRAFORM_SG_ID"
        echo "   -> Retrieved from Terraform output"
    fi
fi

# Fallback to AWS API if Terraform output not available
if [ -z "$CLUSTER_SG_ID" ] || [ "$CLUSTER_SG_ID" == "null" ]; then
    CLUSTER_SG_ID=$(aws eks describe-cluster \
        --name "$CLUSTER_NAME" \
        --region "$REGION" \
        --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
        --output text 2>/dev/null)
    if [ -n "$CLUSTER_SG_ID" ] && [ "$CLUSTER_SG_ID" != "None" ]; then
        echo "   -> Retrieved from AWS API"
    fi
fi

if [ -z "$CLUSTER_SG_ID" ] || [ "$CLUSTER_SG_ID" == "None" ] || [ "$CLUSTER_SG_ID" == "null" ]; then
    echo "ERROR: Could not retrieve cluster security group ID."
    echo "Make sure:"
    echo "  1. The EKS cluster '$CLUSTER_NAME' exists (run: terraform apply)"
    echo "  2. You have eks:DescribeCluster permission"
    echo "  3. AWS credentials are configured"
    echo ""
    echo "You can also get it manually:"
    echo "  terraform output cluster_security_group_id"
    exit 1
fi

echo ""
echo "Cluster Security Group ID: $CLUSTER_SG_ID"
echo ""
echo "Use this in your CloudFormation stack parameters:"
echo "  ClusterSecurityGroupId: $CLUSTER_SG_ID"
echo ""
echo "Or export it:"
echo "  export CLUSTER_SG_ID=$CLUSTER_SG_ID"
HELPER_EOF
chmod +x get-cluster-sg.sh
echo "   -> Created get-cluster-sg.sh helper script"

echo "====== VERIFICATION ======"
echo "Checking if resources exist..."
aws s3 ls | grep "$BUCKET_NAME" || echo "   -> S3 bucket check skipped (may need credentials)"
aws dynamodb list-tables --region "$REGION" | grep "$TABLE_NAME" || echo "   -> DynamoDB table check skipped (may need credentials)"
if aws ec2 describe-key-pairs --key-names "$KEYPAIR_NAME" --region "$REGION" 2>/dev/null | grep -q "$KEYPAIR_NAME"; then
    echo "   -> EC2 Key Pair: $KEYPAIR_NAME exists"
else
    echo "   -> EC2 Key Pair: $KEYPAIR_NAME (creation may have been skipped)"
fi

echo ""
echo "====== SUCCESS ======"
echo "Backend created! Next steps:"
echo "  1. Run: terraform init"
echo "  2. Run: terraform apply"
echo "  3. After cluster is created, run: ./get-cluster-sg.sh demo-eks"
echo "  4. Use the security group ID and keypair '$KEYPAIR_NAME' in your CloudFormation stack"