# Data Sources
data "aws_caller_identity" "current" {}

# Module Definitions
module "network" {
  source = "./modules/network"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  azs                = var.azs
  create_nat_gateway = var.create_nat_gateway
}

module "eks" {
  source = "./modules/eks"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = "demo-eks"

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  cluster_iam_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eksClusterRole"
  node_group_iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eksNodeRole"

  depends_on = [module.network]
}

module "identity" {
  count  = var.enable_identity ? 1 : 0
  source = "./modules/identity"

  eks_oidc_url = module.eks.cluster_oidc_issuer_url

  depends_on = [module.eks, terraform_data.validate_okta_config]
}

# Misc Resources
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