# Data sources to resolve values needed by EKS module
data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  # Using 1.31 (standard support) to avoid extended support costs ($0.10/hr vs $0.60/hr)
  # Versions 1.28-1.30 are in extended support and cost 6x more
  cluster_version = "1.31"

  # Network Glue
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids # Nodes MUST be in private subnets

  # Use existing IAM role if provided (useful for pre-created roles)
  # If var.cluster_iam_role_arn is null, module will create a new role (requires iam:PassRole)
  create_iam_role = var.cluster_iam_role_arn == null
  iam_role_arn    = var.cluster_iam_role_arn

  # CloudWatch logging disabled for cost savings (see COST_OPTIMIZATION_NOTES.md)
  # To enable: set cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  # and create_cloudwatch_log_group = true
  cluster_enabled_log_types              = []
  create_cloudwatch_log_group            = false

  # KMS encryption disabled for cost savings (see COST_OPTIMIZATION_NOTES.md)
  # In production, enable encryption with a KMS key for security compliance
  create_kms_key = false
  cluster_encryption_config = {}

  # OIDC Identity Provider (CRITICAL for Okta)
  # This creates the URL that Okta will trust
  enable_irsa = true

  # Access entries disabled for cost/permission simplicity (see COST_OPTIMIZATION_NOTES.md)
  # In production, configure access_entries here for proper Kubernetes RBAC
  # access_entries = {}

  # Compute (Worker Nodes)
  eks_managed_node_groups = {
    general = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      # Using t3.small for cost savings (~50% cheaper than t3.medium)
      # t3.small: ~$0.0208/hour vs t3.medium: ~$0.0416/hour
      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"  # Change to "SPOT" for 60-70% additional savings
      
      # Use existing IAM role for node groups if provided
      # If var.node_group_iam_role_arn is null, module will create one automatically
      create_iam_role = var.node_group_iam_role_arn == null
      iam_role_arn    = var.node_group_iam_role_arn
      
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