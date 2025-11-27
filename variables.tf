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
  description = "Okta org slug (e.g., dev-123456). Found in your Okta admin URL: https://YOUR_ORG.okta.com. IMPORTANT: Do NOT include '-admin' - use just the org name (e.g., 'integrator-4772467' not 'integrator-4772467-admin')"
  type        = string
  default     = ""
}

variable "okta_api_token" {
  description = "API token for the Okta org. Create one in Okta Admin > Security > API > Tokens"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_identity" {
  description = "Feature flag to control whether the Okta identity module is applied."
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "create_nat_gateway" {
  description = "Creates NAT Gateway when true. Set to false to delay creation until after EKS cluster for cost savings."
  type        = bool
  default     = true
}
