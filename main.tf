# main.tf

# Data sources for default VPC and subnets
data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

# Get all default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get subnet details to filter out us-east-1e
data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Filter subnets to exclude us-east-1e
locals {
  default_subnet_ids = [
    for subnet in data.aws_subnet.default :
    subnet.id if subnet.availability_zone != "us-east-1e"
  ]
}

# Validate Okta configuration when identity is enabled
# This precondition ensures required Okta variables are set when enable_identity is true
resource "terraform_data" "validate_okta_config" {
  lifecycle {
    precondition {
      # If identity is enabled, org name and token must NOT be empty
      condition = !var.enable_identity || (
        length(trimspace(var.okta_org_name)) > 0 &&
        length(trimspace(var.okta_api_token)) > 0 &&
        !can(regex("-admin$", var.okta_org_name))
      )
      error_message = "When enable_identity is true, you must provide okta_org_name (without '-admin') and okta_api_token."
    }
  }
}

# Security Group for EKS Node Groups
# This can be created by setup.sh or by Terraform (if setup.sh wasn't run)
# Try to find existing security group (created by setup.sh)
data "aws_security_groups" "eks_nodes_existing" {
  filter {
    name   = "group-name"
    values = ["okta-eks-nodes-sg"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create security group if it doesn't exist (fallback if setup.sh wasn't run)
resource "aws_security_group" "eks_nodes" {
  count       = length(data.aws_security_groups.eks_nodes_existing.ids) == 0 ? 1 : 0
  name        = "okta-eks-nodes-sg"
  description = "Security group for EKS node groups (created by Terraform)"
  vpc_id      = data.aws_vpc.default.id

  # Allow all traffic from itself (node-to-node pod communication)
  ingress {
    description = "Node-to-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Allow SSH from VPC CIDR
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  # Allow all outbound traffic (required for pulling images, etc.)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "okta-eks-nodes-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Use existing security group if it exists, otherwise use the one we created
locals {
  node_security_group_id = length(data.aws_security_groups.eks_nodes_existing.ids) > 0 ? data.aws_security_groups.eks_nodes_existing.ids[0] : aws_security_group.eks_nodes[0].id
}

# Deploy EKS Cluster
module "eks" {
  source = "./modules/eks"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = "demo-eks"

  # Use Default VPC and Default Subnets (filtered to exclude us-east-1e)
  vpc_id             = data.aws_vpc.default.id
  private_subnet_ids = local.default_subnet_ids

  # Hardcoded IAM Role ARNs (must exist in the account)
  cluster_iam_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eksClusterRole"
  node_group_iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eksNodeRole"
}

# Add rule to allow traffic from cluster security group to node security group
# This is required for EKS cluster-to-node communication
resource "aws_security_group_rule" "cluster_to_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = local.node_security_group_id
  description              = "Allow all traffic from EKS cluster security group"
}

# 3. Deploy Identity (Okta Configuration)
# Enabled via var.enable_identity to keep local testing simple.
module "identity" {
  count  = var.enable_identity ? 1 : 0
  source = "./modules/identity"

  eks_oidc_url = module.eks.cluster_oidc_issuer_url

  depends_on = [module.eks, terraform_data.validate_okta_config]
}