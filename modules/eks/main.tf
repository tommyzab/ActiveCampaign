module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.27"

  # Network Glue
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids # Nodes MUST be in private subnets

  # OIDC Identity Provider (CRITICAL for Okta)
  # This creates the URL that Okta will trust
  enable_irsa = true 

  # Access Control
  # Grants the creator (YOU) admin rights immediately
  manage_aws_auth_configmap = true
  aws_auth_users = [
    {
      userarn  = data.aws_caller_identity.current.arn
      username = "admin-user"
      groups   = ["system:masters"]
    },
  ]

  # Compute (Worker Nodes)
  eks_managed_node_groups = {
    general = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      labels = {
        role = "general"
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Helper to get current account ID
data "aws_caller_identity" "current" {}