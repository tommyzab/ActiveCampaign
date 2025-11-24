output "okta_client_id" {
  value = okta_app_oauth.eks_client.client_id
}

output "okta_issuer_url" {
  # This is constructed based on your provider config
  value = "https://dev-YOUR-ORG.okta.com" 
}