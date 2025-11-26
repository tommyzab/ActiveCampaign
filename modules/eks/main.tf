module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  # Network Configuration
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # IAM Roles - DO NOT CREATE (use existing roles)
  create_iam_role = false
  iam_role_arn    = var.cluster_iam_role_arn

  # IRSA enabled to expose OIDC issuer URL (required for Okta integration)
  # This creates the OIDC endpoint that Okta will trust
  enable_irsa = true

  # CloudWatch logging disabled
  cluster_enabled_log_types              = []
  create_cloudwatch_log_group            = false

  # KMS encryption disabled
  create_kms_key = false
  cluster_encryption_config = {}

  # Access entries disabled
  # access_entries = {}

  eks_managed_node_groups = {}
  

  self_managed_node_groups = {}

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}