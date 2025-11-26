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

# Okta provider configuration
# Note: The provider will attempt validation during terraform plan even when enable_identity is false
# This is a known limitation - Terraform initializes all providers regardless of whether they're used
# When enable_identity=false, module.identity has count=0, so the provider won't actually be used
# The validation error can be ignored in CI/CD when identity is disabled
provider "okta" {
  org_name  = var.enable_identity ? var.okta_org_name : "dev-000000"
  base_url  = "okta.com"
  api_token = var.enable_identity ? var.okta_api_token : "00DummyTokenForValidationWhenIdentityDisabled1234567890abcdef"
}
