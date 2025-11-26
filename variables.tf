variable "project_name" {
  description = "Canonical project prefix used for tagging and resource names."
  type        = string
  default     = "okta-eks-lab"
}

variable "environment" {
  description = "Deployment stage (dev, staging, prod). Used for tagging."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region that hosts the VPC/EKS stack."
  type        = string
  default     = "us-east-1"
}

variable "cluster_iam_role_arn" {
  description = "ARN of existing IAM role to use for EKS cluster. Leave empty to let module create one (requires iam:PassRole permission). Useful if you have pre-created roles with specific policies."
  type        = string
  default     = null
}

variable "node_group_iam_role_arn" {
  description = "ARN of existing IAM role to use for EKS node groups. If not provided, module will create one automatically. In production, cluster and node group roles should be separate."
  type        = string
  default     = null
}

variable "create_nat_gateway" {
  description = "Whether to create NAT Gateway. Set to false to create EKS cluster first (saves costs during cluster creation), then set to true and apply again. Default: true (creates immediately)."
  type        = bool
  default     = true
}

# variable "okta_org_name" {
#   description = "Okta org slug (e.g., dev-123456). Optional for local runs without identity provisioning."
#   type        = string
#   default     = ""
#
#   validation {
#     condition     = !var.enable_identity || length(trim(var.okta_org_name)) > 0
#     error_message = "okta_org_name must be set when enable_identity is true."
#   }
# }
#
# variable "okta_api_token" {
#   description = "API token for the Okta org. Leave empty to skip the identity module."
#   type        = string
#   default     = ""
#   sensitive   = true
#
#   validation {
#     condition     = !var.enable_identity || length(trim(var.okta_api_token)) > 0
#     error_message = "okta_api_token must be set when enable_identity is true."
#   }
# }
#
# variable "enable_identity" {
#   description = "Feature flag to control whether the Okta identity module is applied."
#   type        = bool
#   default     = false
# }

