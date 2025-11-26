# main.tf

# 1. Deploy Networking (The Foundation)
module "network" {
  source = "./modules/network"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr        = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  
  # Delay NAT Gateway creation until after EKS cluster (cost optimization)
  # Set to false to create cluster first, then manually enable NAT Gateway later
  create_nat_gateway = var.create_nat_gateway
}

# 2. Deploy Compute (EKS Cluster)
module "eks" {
  source = "./modules/eks"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = "${var.project_name}-cluster"

  # Connect to Networking Module
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  # Optional: Use existing IAM role (useful if you have pre-created roles)
  # If not provided, module will create one (requires iam:PassRole permission)
  cluster_iam_role_arn = var.cluster_iam_role_arn
  
  # Optional: Use existing IAM role for node groups
  # If not provided, module will create one automatically
  node_group_iam_role_arn = var.node_group_iam_role_arn

  # Explicit dependency to ensure network is fully provisioned before EKS
  depends_on = [module.network]
}

# 3. Deploy Identity (Okta Configuration)
# Enabled via var.enable_identity to keep local testing simple.
# NOTE: Commented out for local testing - Okta Developer platform requires corporate email validation
# module "identity" {
#   count  = var.enable_identity ? 1 : 0
#   source = "./modules/identity"
#
#   eks_oidc_url = module.eks.cluster_oidc_issuer_url
#
#   depends_on = [module.eks]
# }