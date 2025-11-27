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
  org_name  = var.okta_org_name
  base_url  = "okta.com"
  api_token = var.okta_api_token
}
