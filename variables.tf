# variables.tf

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project Name (used for tagging)"
  type        = string
  default     = "okta-eks-assignment"
}

variable "environment" {
  description = "Environment Name"
  type        = string
  default     = "dev"
}

# --- Okta Secrets (Required for Provider, even if module is skipped) ---
variable "okta_org_name" {
  description = "Okta Org Name (e.g. dev-123456)"
  type        = string
  default     = "dev-MOCK" # Default allows 'terraform plan' to pass without prompt
}

variable "okta_api_token" {
  description = "Okta API Token"
  type        = string
  sensitive   = true
  default     = "MOCK_TOKEN" # Default allows 'terraform plan' to pass
}