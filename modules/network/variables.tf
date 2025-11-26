variable "vpc_cidr" { type = string }
variable "project_name" { type = string }
variable "environment" { type = string }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "azs" { type = list(string) }
variable "create_nat_gateway" {
  description = "Whether to create NAT Gateway. Set to false to delay creation until after EKS cluster (cost savings)."
  type        = bool
  default     = true
}