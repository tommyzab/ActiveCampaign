data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

# Retrieves all subnets in default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Gets subnet details to filter by availability zone
data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Filters out us-east-1e subnet from default subnets list
locals {
  default_subnet_ids = [
    for subnet in data.aws_subnet.default :
    subnet.id if subnet.availability_zone != "us-east-1e"
  ]
}

# Validates Okta variables are set when enable_identity is true
resource "terraform_data" "validate_okta_config" {
  lifecycle {
    precondition {
      condition = !var.enable_identity || (
        length(trimspace(var.okta_org_name)) > 0 &&
        length(trimspace(var.okta_api_token)) > 0 &&
        !can(regex("-admin$", var.okta_org_name))
      )
      error_message = "When enable_identity is true, you must provide okta_org_name (without '-admin') and okta_api_token."
    }
  }
}

# Checks if node security group exists (created by setup.sh)
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

# Creates node security group if setup.sh didn't create it
resource "aws_security_group" "eks_nodes" {
  count       = length(data.aws_security_groups.eks_nodes_existing.ids) == 0 ? 1 : 0
  name        = "okta-eks-nodes-sg"
  description = "Security group for EKS node groups (created by Terraform)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Node-to-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

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

# Uses existing security group if found, otherwise uses Terraform-created one
locals {
  node_security_group_id = length(data.aws_security_groups.eks_nodes_existing.ids) > 0 ? data.aws_security_groups.eks_nodes_existing.ids[0] : aws_security_group.eks_nodes[0].id
}

# Deploys EKS cluster with IRSA enabled for Okta integration
module "eks" {
  source = "./modules/eks"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = "demo-eks"

  vpc_id             = data.aws_vpc.default.id
  private_subnet_ids = local.default_subnet_ids

  cluster_iam_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eksClusterRole"
  node_group_iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eksNodeRole"
}

# Allows cluster security group to communicate with node security group
resource "aws_security_group_rule" "cluster_to_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = local.node_security_group_id
  description              = "Allow all traffic from EKS cluster security group"
}

# Configures Okta groups, rules, and OIDC app for EKS access (enabled via var.enable_identity)
module "identity" {
  count  = var.enable_identity ? 1 : 0
  source = "./modules/identity"

  eks_oidc_url = module.eks.cluster_oidc_issuer_url

  depends_on = [module.eks, terraform_data.validate_okta_config]
}