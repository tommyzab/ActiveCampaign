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

variable "okta_org_name" {
  description = "Okta org slug (e.g., dev-123456). Optional for local runs without identity provisioning."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_identity || length(trim(var.okta_org_name)) > 0
    error_message = "okta_org_name must be set when enable_identity is true."
  }
}

variable "okta_api_token" {
  description = "API token for the Okta org. Leave empty to skip the identity module."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.enable_identity || length(trim(var.okta_api_token)) > 0
    error_message = "okta_api_token must be set when enable_identity is true."
  }
}

variable "enable_identity" {
  description = "Feature flag to control whether the Okta identity module is applied."
  type        = bool
  default     = false
}

