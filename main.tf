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

# 3. Deploy Identity (Okta Configuration)
# Enabled via var.enable_identity to keep local testing simple.
module "identity" {
  count  = var.enable_identity ? 1 : 0
  source = "./modules/identity"

  eks_oidc_url = module.eks.cluster_oidc_issuer_url

  depends_on = [module.eks]
}