output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "The API Endpoint of the cluster"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Command to configure kubectl locally"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster. Use this in CloudFormation stack for unmanaged node groups."
  value       = module.eks.cluster_security_group_id
}