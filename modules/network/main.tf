# 1. The VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# 2. Internet Gateway (Entry point)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  depends_on = [aws_vpc.main]

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 3. Public Subnets (For Load Balancers)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  depends_on = [aws_vpc.main]

  tags = {
    Name                     = "${var.project_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1" # Required for Public ALBs
  }
}

# 4. Private Subnets (For EKS Nodes)
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  depends_on = [aws_vpc.main]

  tags = {
    Name                              = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1" # Required for Internal ALBs
  }
}

# 5. NAT Gateway (Single one for cost savings in Lab)
# Created conditionally and after EKS cluster to minimize costs during cluster creation
resource "aws_eip" "nat" {
  count  = var.create_nat_gateway ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  count         = var.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id # NAT lives in Public
  
  # NAT Gateway can be created after EKS cluster control plane to save costs
  # Nodes will be created after NAT Gateway is ready
  depends_on = [aws_eip.nat, aws_subnet.public, aws_internet_gateway.main]
  
  tags = { Name = "${var.project_name}-nat" }
}

# 6. Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  depends_on = [aws_vpc.main, aws_internet_gateway.main]
  
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  dynamic "route" {
    for_each = var.create_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }
  
  depends_on = [aws_vpc.main, aws_nat_gateway.main]
  
  tags = { Name = "${var.project_name}-private-rt" }
}

# 7. Route Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id

  depends_on = [aws_subnet.public, aws_route_table.public]
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id

  depends_on = [aws_subnet.private, aws_route_table.private]
}