# main.tf

# 1. Deploy Networking (The Foundation)
module "network" {
  source = "${path.module}/modules/network"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr        = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
}

# 2. Deploy Compute (EKS Cluster)
module "eks" {
  source = "${path.module}/modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  cluster_name       = "${var.project_name}-cluster"
  
  # Connect to Networking Module
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
}

# 3. Deploy Identity (Okta Configuration)
# Enabled via var.enable_identity to keep local testing simple.
module "identity" {
  count  = var.enable_identity ? 1 : 0
  source = "${path.module}/modules/identity"

  eks_oidc_url = module.eks.cluster_oidc_issuer_url

  depends_on = [module.eks]
}