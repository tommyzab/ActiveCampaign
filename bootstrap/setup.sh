#!/bin/bash
set -e # Stop script immediately on first error

# Disable AWS CLI pager to prevent interactive prompts
export AWS_PAGER=""

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

echo "4. Creating Security Group for EKS nodes..."
SG_NAME="okta-eks-nodes-sg"
# Get default VPC ID
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --region "$REGION" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null)

if [ -z "$DEFAULT_VPC_ID" ] || [ "$DEFAULT_VPC_ID" == "None" ]; then
    echo "   -> Warning: Could not find default VPC. Skipping security group creation."
    NODE_SG_ID=""
else
    # Check if security group already exists
    EXISTING_SG=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$DEFAULT_VPC_ID" \
        --region "$REGION" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null)
    
    if [ -n "$EXISTING_SG" ] && [ "$EXISTING_SG" != "None" ]; then
        echo "   -> Security group '$SG_NAME' already exists: $EXISTING_SG"
        NODE_SG_ID="$EXISTING_SG"
    else
        # Create security group
        NODE_SG_ID=$(aws ec2 create-security-group \
            --group-name "$SG_NAME" \
            --description "Security group for EKS node groups (created by setup.sh)" \
            --vpc-id "$DEFAULT_VPC_ID" \
            --region "$REGION" \
            --query 'GroupId' \
            --output text 2>/dev/null)
        
        if [ -n "$NODE_SG_ID" ] && [ "$NODE_SG_ID" != "None" ]; then
            echo "   -> Security group created: $NODE_SG_ID"
            
            # Add inbound rules for EKS nodes
            # 1. Allow all traffic from itself (node-to-node pod communication)
            #    This is required for pods to communicate across nodes
            aws ec2 authorize-security-group-ingress \
                --group-id "$NODE_SG_ID" \
                --protocol -1 \
                --source-group "$NODE_SG_ID" \
                --region "$REGION" 2>/dev/null || echo "   -> Warning: Could not add self-referencing rule"
            
            # 2. Allow traffic from cluster security group (will be added after cluster creation)
            #    This is handled by get-cluster-sg.sh script after terraform apply
            #    Required ports: 443 (HTTPS from control plane), 10250 (kubelet)
            
            # 3. SSH access - RESTRICTED: Only allow from VPC CIDR (not 0.0.0.0/0)
            #    Get VPC CIDR for more secure SSH access
            VPC_CIDR=$(aws ec2 describe-vpcs \
                --vpc-ids "$DEFAULT_VPC_ID" \
                --region "$REGION" \
                --query 'Vpcs[0].CidrBlock' \
                --output text 2>/dev/null)
            
            if [ -n "$VPC_CIDR" ] && [ "$VPC_CIDR" != "None" ]; then
                aws ec2 authorize-security-group-ingress \
                    --group-id "$NODE_SG_ID" \
                    --protocol tcp \
                    --port 22 \
                    --cidr "$VPC_CIDR" \
                    --region "$REGION" 2>/dev/null || echo "   -> Warning: Could not add SSH rule from VPC"
                echo "   -> SSH access restricted to VPC CIDR: $VPC_CIDR"
            else
                # Fallback: Allow SSH from VPC private IP range (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
                # This is more secure than 0.0.0.0/0 but still allows from any private network
                echo "   -> Warning: Could not determine VPC CIDR. SSH access not configured."
                echo "   -> You can manually add SSH access later if needed."
            fi
            
            # Note: Outbound traffic is allowed by default (required for pulling images, etc.)
            # Specific outbound rules:
            # - Port 443 (HTTPS) to ECR and public registries
            # - Port 53 (DNS) for service discovery
            # - All traffic to cluster security group (for kubelet on port 10250)
            # These are typically handled automatically, but cluster SG rule is added later
            
            echo "   -> Security group rules configured"
            echo "   -> Note: Cluster SG rule will be added after cluster creation via get-cluster-sg.sh"
        else
            echo "   -> Warning: Could not create security group (may need permissions). Continuing..."
            NODE_SG_ID=""
        fi
    fi
fi

echo "5. Generating backend.tf..."
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

echo "6. Creating helper script to get cluster security group ID..."
cat > bootstrap/get-cluster-sg.sh <<'HELPER_EOF'
#!/bin/bash
# Helper script to get the EKS cluster security group ID after terraform apply

# Disable AWS CLI pager to prevent interactive prompts
export AWS_PAGER=""

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

# Also update the node security group to allow traffic from cluster SG
NODE_SG_NAME="okta-eks-nodes-sg"
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --region "$REGION" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null)

if [ -n "$DEFAULT_VPC_ID" ] && [ "$DEFAULT_VPC_ID" != "None" ]; then
    NODE_SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$NODE_SG_NAME" "Name=vpc-id,Values=$DEFAULT_VPC_ID" \
        --region "$REGION" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null)
    
    if [ -n "$NODE_SG_ID" ] && [ "$NODE_SG_ID" != "None" ]; then
        echo "Updating node security group ($NODE_SG_ID) to allow traffic from cluster..."
        # Check if rule already exists
        EXISTING_RULE=$(aws ec2 describe-security-group-rules \
            --filters "Name=group-id,Values=$NODE_SG_ID" "Name=referenced-group-info.group-id,Values=$CLUSTER_SG_ID" \
            --region "$REGION" \
            --query 'SecurityGroupRules[0].SecurityGroupRuleId' \
            --output text 2>/dev/null)
        
        if [ -z "$EXISTING_RULE" ] || [ "$EXISTING_RULE" == "None" ]; then
            # Add rule to allow all traffic from cluster security group
            aws ec2 authorize-security-group-ingress \
                --group-id "$NODE_SG_ID" \
                --protocol -1 \
                --source-group "$CLUSTER_SG_ID" \
                --region "$REGION" 2>/dev/null && echo "   -> Added rule: Allow all traffic from cluster SG"
        else
            echo "   -> Rule already exists (traffic from cluster SG already allowed)"
        fi
    fi
fi
HELPER_EOF
chmod +x bootstrap/get-cluster-sg.sh
echo "   -> Created bootstrap/get-cluster-sg.sh helper script"

echo ""
echo "====== VERIFICATION ======"
echo "Checking if resources exist..."
aws s3 ls | grep "$BUCKET_NAME" || echo "   -> S3 bucket check skipped (may need credentials)"
aws dynamodb list-tables --region "$REGION" | grep "$TABLE_NAME" || echo "   -> DynamoDB table check skipped (may need credentials)"
if aws ec2 describe-key-pairs --key-names "$KEYPAIR_NAME" --region "$REGION" 2>/dev/null | grep -q "$KEYPAIR_NAME"; then
    echo "   -> EC2 Key Pair: $KEYPAIR_NAME exists"
else
    echo "   -> EC2 Key Pair: $KEYPAIR_NAME (creation may have been skipped)"
fi
if [ -n "$NODE_SG_ID" ] && [ "$NODE_SG_ID" != "None" ]; then
    echo "   -> Security Group: $NODE_SG_ID ($SG_NAME)"
else
    echo "   -> Security Group: (creation may have been skipped)"
fi

echo ""
echo "====== SUCCESS ======"
echo "Backend created! Resources ready:"
if [ -n "$NODE_SG_ID" ] && [ "$NODE_SG_ID" != "None" ]; then
    echo "  - Node Security Group ID: $NODE_SG_ID"
fi
echo "  - Key Pair Name: $KEYPAIR_NAME"
echo ""
echo "Next steps:"
echo "  1. Run: terraform init"
echo "  2. Run: terraform apply"
echo "  3. After cluster is created, update the node security group to allow traffic from cluster SG:"
echo "     ./bootstrap/get-cluster-sg.sh demo-eks"
echo "     (Note: Terraform will also add this rule automatically if you run terraform apply)"
