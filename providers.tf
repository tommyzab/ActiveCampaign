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
  # When identity is disabled, use dummy values to prevent provider validation errors during init
  # The provider won't actually be used when enable_identity is false (module.identity has count=0)
  # but Terraform still initializes all providers during terraform init
  org_name  = var.enable_identity ? var.okta_org_name : coalesce(var.okta_org_name, "dummy-org")
  base_url  = "okta.com"
  api_token = var.enable_identity ? var.okta_api_token : coalesce(var.okta_api_token, "00DummyTokenForValidationWhenIdentityDisabled1234567890abcdef")
}