# main.tf

# 1. Deploy Networking (The Foundation)
module "network" {
  source = "./modules/network"

  project_name    = var.project_name
  environment     = var.environment
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"] # First 2 zones
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
}

# 2. Deploy Compute (EKS Cluster)
module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  cluster_name       = "${var.project_name}-cluster"
  
  # Connect to Networking Module
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
}

# 3. Deploy Identity (Okta Configuration)
# -----------------------------------------------------------
# NOTE: This module is commented out for local testing because
# we do not have a live Okta API Token in this lab environment.
# In production, this would be uncommented to provision
# the Okta Groups and OIDC App automatically.
# -----------------------------------------------------------
/*
module "identity" {
  source = "./modules/identity"

  # In a real integration, we would pass the EKS OIDC URL here
  # if we were configuring the Trust relationship explicitly.
  # eks_oidc_url = module.eks.cluster_oidc_issuer_url
  
  depends_on = [ module.eks ]
}
*/