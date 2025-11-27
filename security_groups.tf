resource "aws_security_group" "eks_nodes" {
  name        = "okta-eks-nodes-sg"
  description = "Security group for EKS node groups (created by Terraform)"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "okta-eks-nodes-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

locals {
  node_security_group_id = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "cluster_to_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = local.node_security_group_id
}

