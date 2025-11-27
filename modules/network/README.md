# Network Module

Creates VPC infrastructure with public and private subnets for EKS cluster deployment.

## Features

- VPC with DNS support and hostnames enabled
- Public and private subnets across multiple availability zones
- Internet Gateway for public subnet internet access
- Single NAT Gateway for cost optimization (optional)
- Route tables for public and private subnets
- Kubernetes-specific subnet tags for ELB integration

## Usage

```hcl
module "network" {
  source = "./modules/network"

  project_name      = "okta-eks-lab"
  environment       = "dev"
  vpc_cidr          = "10.0.0.0/16"
  public_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets   = ["10.0.10.0/24", "10.0.20.0/24"]
  azs               = ["us-east-1a", "us-east-1b"]
  create_nat_gateway = true
}
```

## Requirements

- AWS provider >= 5.0
- Subnets must be within VPC CIDR range
- Minimum of 2 availability zones recommended for high availability
- Public and private subnet lists must match the number of AZs

## Cost Considerations

- Uses a single NAT Gateway instead of one per AZ to reduce costs
- NAT Gateway creation can be delayed (`create_nat_gateway = false`) until after EKS cluster creation for initial cost savings
- Minimal but effective subnet structure
- No VPC Flow Logs to avoid additional logging costs

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| vpc_cidr | CIDR block for VPC | string | yes | - |
| project_name | Project name prefix for resource naming | string | yes | - |
| environment | Deployment environment (dev, staging, prod) | string | yes | - |
| public_subnets | List of CIDR blocks for public subnets | list(string) | yes | - |
| private_subnets | List of CIDR blocks for private subnets | list(string) | yes | - |
| azs | List of availability zones | list(string) | yes | - |
| create_nat_gateway | Creates NAT Gateway when true. Set to false to delay creation until after EKS cluster for cost savings | bool | no | true |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| private_subnet_ids | List of private subnet IDs (tagged for internal ELB) |
| public_subnet_ids | List of public subnet IDs (tagged for external ELB) |

## Subnet Tags

The module automatically tags subnets for Kubernetes ELB integration:
- Public subnets: `kubernetes.io/role/elb = "1"`
- Private subnets: `kubernetes.io/role/internal-elb = "1"`

These tags enable Kubernetes to automatically discover and use the appropriate subnets for load balancer creation.

