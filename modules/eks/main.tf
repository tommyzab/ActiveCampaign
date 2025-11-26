module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  create_iam_role = false
  iam_role_arn    = var.cluster_iam_role_arn

  enable_irsa = true

  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  create_kms_key            = false
  cluster_encryption_config = {}

  eks_managed_node_groups = {}

  self_managed_node_groups = {}

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}