variable "eks_oidc_url" {
  description = "OIDC issuer URL from the EKS control plane, used for future trust automation."
  type        = string
  default     = ""
}

