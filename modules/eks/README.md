# EKS Module

Creates an Amazon EKS (Elastic Kubernetes Service) cluster with IRSA (IAM Roles for Service Accounts) enabled.

## Features

- EKS cluster with Kubernetes version 1.30
- IRSA (IAM Roles for Service Accounts) enabled for pod-level IAM permissions
- OIDC provider integration for service account authentication
- Uses existing IAM roles (does not create new roles)
- Optimized for cost with minimal logging and encryption disabled
- Designed for unmanaged node groups (node groups created separately via CloudFormation)

## Usage

```hcl
module "eks" {
  source = "./modules/eks"

  project_name = "okta-eks-lab"
  environment  = "dev"
  cluster_name = "demo-eks"

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  cluster_iam_role_arn    = "arn:aws:iam::123456789012:role/eksClusterRole"
  node_group_iam_role_arn = "arn:aws:iam::123456789012:role/eksNodeRole"
}
```

## Requirements

- AWS provider >= 5.0
- Existing IAM roles for cluster and node groups (must be created separately)
- VPC and private subnets (typically from network module)
- Appropriate IAM permissions for EKS cluster creation

## Prerequisites

Before using this module, ensure you have:

1. **Cluster IAM Role** with the following trust policy:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {"Service": "eks.amazonaws.com"},
       "Action": "sts:AssumeRole"
     }]
   }
   ```
   And attach the `AmazonEKSClusterPolicy` managed policy.

2. **Node Group IAM Role** with the following trust policy:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {"Service": "ec2.amazonaws.com"},
       "Action": "sts:AssumeRole"
     }]
   }
   ```
   And attach the following managed policies:
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEKS_CNI_Policy`
   - `AmazonEC2ContainerRegistryReadOnly`

## Cost Considerations

- CloudWatch logging disabled (`create_cloudwatch_log_group = false`)
- KMS encryption disabled (`create_kms_key = false`)
- No managed node groups created (use CloudFormation for unmanaged node groups)
- Minimal resource footprint for cost optimization

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| cluster_name | Name of the EKS cluster | string | yes |
| vpc_id | ID of the VPC where the cluster will be created | string | yes |
| private_subnet_ids | List of private subnet IDs for the cluster | list(string) | yes |
| project_name | Project name prefix for resource tagging | string | yes |
| environment | Deployment environment (dev, staging, prod) | string | yes |
| cluster_iam_role_arn | ARN of existing IAM role to use for EKS cluster | string | yes |
| node_group_iam_role_arn | ARN of existing IAM role to use for EKS node groups | string | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster_endpoint | Endpoint for your Kubernetes API server |
| cluster_name | Kubernetes Cluster Name |
| cluster_oidc_issuer_url | The URL on the EKS cluster for the OpenID Connect identity provider |
| oidc_provider_arn | The ARN of the OIDC Provider (for IRSA) |
| cluster_security_group_id | Security group ID attached to the EKS cluster (required for CloudFormation node group stacks) |

## IRSA (IAM Roles for Service Accounts)

This module enables IRSA, which allows Kubernetes service accounts to assume IAM roles. This is essential for:
- Pod-level AWS API access
- Secure credential management
- Fine-grained IAM permissions per application

The OIDC provider is automatically created and configured when `enable_irsa = true`.

## Node Groups

This module does **not** create node groups. Node groups should be created separately using:
- CloudFormation stacks (for unmanaged node groups)
- AWS Console
- AWS CLI
- Separate Terraform resources

Use the `cluster_security_group_id` output when creating node groups to ensure proper networking.

## Post-Deployment

After the cluster is created:

1. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --name <cluster_name> --region <region>
   ```

2. Verify cluster access:
   ```bash
   kubectl get nodes
   ```

3. Create node groups using the `cluster_security_group_id` output.

