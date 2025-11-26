terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 5.0" }
    okta = { source = "okta/okta", version = "~> 4.0" }
  }
}

provider "aws" {
  region = var.region
}

provider "okta" {
  # Use empty strings when identity is disabled to prevent provider validation errors
  # The provider will not be used when enable_identity is false, but it still needs valid values
  org_name  = var.enable_identity ? var.okta_org_name : ""
  base_url  = "okta.com"
  api_token = var.enable_identity ? var.okta_api_token : ""
}