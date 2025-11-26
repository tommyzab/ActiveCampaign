#!/bin/bash
# Helper script to get the EKS cluster security group ID after terraform apply
# This is needed for CloudFormation stack that creates unmanaged node groups

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
REGION="${2:-us-east-1}"
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

echo ""
echo "Use this in your CloudFormation stack parameters:"
echo "  ClusterSecurityGroupId: $CLUSTER_SG_ID"
echo "  NodeSecurityGroupId: $NODE_SG_ID"
echo ""
echo "Or export them:"
echo "  export CLUSTER_SG_ID=$CLUSTER_SG_ID"
if [ -n "$NODE_SG_ID" ] && [ "$NODE_SG_ID" != "None" ]; then
    echo "  export NODE_SG_ID=$NODE_SG_ID"
fi
