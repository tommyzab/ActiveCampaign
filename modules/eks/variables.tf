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
  description = "ARN of existing IAM role to use for EKS cluster. If not provided, module will create one (requires iam:PassRole permission)."
  type        = string
  default     = null
}

variable "node_group_iam_role_arn" {
  description = "ARN of existing IAM role to use for EKS node groups. If not provided, module will create one. For lab environments, you may use the same role as cluster_iam_role_arn."
  type        = string
  default     = null
}