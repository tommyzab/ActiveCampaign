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

# IAM Role ARNs are now hardcoded in main.tf using data.aws_caller_identity.current.account_id
# No variables needed for IAM roles - they are automatically constructed

variable "okta_org_name" {
  description = "Okta org slug (e.g., dev-123456). Found in your Okta admin URL: https://YOUR_ORG.okta.com. IMPORTANT: Do NOT include '-admin' - use just the org name (e.g., 'integrator-4772467' not 'integrator-4772467-admin')"
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_identity || length(trimspace(var.okta_org_name)) > 0
    error_message = "okta_org_name must be set when enable_identity is true."
  }
  
  validation {
    condition     = !var.enable_identity || !can(regex("-admin$", var.okta_org_name))
    error_message = "okta_org_name should NOT include '-admin'. Use just the org name (e.g., 'integrator-4772467' not 'integrator-4772467-admin')."
  }
}

variable "okta_api_token" {
  description = "API token for the Okta org. Create one in Okta Admin > Security > API > Tokens"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.enable_identity || length(trimspace(var.okta_api_token)) > 0
    error_message = "okta_api_token must be set when enable_identity is true."
  }
}

variable "enable_identity" {
  description = "Feature flag to control whether the Okta identity module is applied."
  type        = bool
  default     = false
}

