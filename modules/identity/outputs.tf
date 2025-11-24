output "admin_group_id" {
  description = "Okta group ID that maps to Kubernetes cluster-admin."
  value       = okta_group.k8s_admins.id
}

output "okta_client_id" {
  description = "Client ID of the Okta OIDC application provisioned for EKS access."
  value       = okta_app_oauth.eks_client.client_id
}

output "oidc_placeholder" {
  description = "Echoes the supplied EKS OIDC issuer URL for documentation/runbook purposes."
  value       = var.eks_oidc_url
}

