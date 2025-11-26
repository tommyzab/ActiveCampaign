variable "cluster_name" { 
    type = string 
    }
variable "vpc_id" { 
    type = string 
    }

variable "private_subnet_ids" { 
    type = list(string) 
    }

variable "environment" { 
    type = string 
    }

variable "project_name" { 
    type = string 
    }

variable "cluster_iam_role_arn" {
  description = "ARN of existing IAM role to use for EKS cluster. Required - must be provided."
  type        = string
}

variable "node_group_iam_role_arn" {
  description = "ARN of existing IAM role to use for EKS node groups. Required - must be provided."
  type        = string
}