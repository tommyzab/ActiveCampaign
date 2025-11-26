terraform {
  required_providers {
    okta = {
      source  = "okta/okta"
      version = "~> 4.0"
    }
  }
}

# 1. Create the K8s Admin Group
resource "okta_group" "k8s_admins" {
  name        = "k8s-cluster-admins"
  description = "Admins with system:masters access to EKS"
}

# 2. The Dynamic Rule
resource "okta_group_rule" "engineering_rule" {
  name              = "Auto-Assign Engineering"
  group_assignments = [okta_group.k8s_admins.id]
  expression_value  = "user.department eq \"Engineering\""
  status            = "ACTIVE"
}

# 3. The OIDC App (Cleaned up)
resource "okta_app_oauth" "eks_client" {
  label          = "EKS Cluster Access"
  type           = "native"
  grant_types    = ["authorization_code", "refresh_token"]
  response_types = ["id_token"]
  
  redirect_uris  = ["http://localhost:8000/callback", "http://localhost:18000/callback"]
  
  # REMOVED: groups = [...] (This caused the error)
}

# 4. The Assignment (The Fix)
# We link the Group to the App here instead
resource "okta_app_group_assignment" "assign_admins" {
  app_id   = okta_app_oauth.eks_client.id
  group_id = okta_group.k8s_admins.id
}