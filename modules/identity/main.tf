terraform {
  required_providers {
    okta = {
      source  = "okta/okta"
      version = "~> 4.0"
    }
  }
}

# Creates Okta group that grants EKS cluster-admin access
resource "okta_group" "k8s_admins" {
  name        = "k8s-cluster-admins"
  description = "Admins with system:masters access to EKS"
}

# Auto-assigns users with department="Engineering" to k8s-cluster-admins group
resource "okta_group_rule" "engineering_rule" {
  name              = "Auto-Assign Engineering"
  group_assignments = [okta_group.k8s_admins.id]
  expression_value  = "user.department eq \"Engineering\""
  status            = "ACTIVE"
}

# Creates OIDC app that connects users to EKS cluster via authorization code flow
resource "okta_app_oauth" "eks_client" {
  label          = "EKS Cluster Access"
  type           = "native"
  grant_types    = ["authorization_code", "refresh_token"]
  response_types = ["code"]

  redirect_uris = ["http://localhost:8000/callback", "http://localhost:18000/callback"]
}

# Links k8s-cluster-admins group to OIDC app to grant EKS access
resource "okta_app_group_assignment" "assign_admins" {
  app_id   = okta_app_oauth.eks_client.id
  group_id = okta_group.k8s_admins.id
}