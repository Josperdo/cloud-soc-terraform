# ─── VPC ─────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.prefix}-vpc" })
}

# ─── Subnets ─────────────────────────────────────────────────────────────────
# Management subnet is public so the EC2 instance can reach SSM endpoints
# outbound over HTTPS. No inbound ports are opened — SSM initiates from AWS.

resource "aws_subnet" "management" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.management_subnet_cidr
  availability_zone       = "${var.region}a" # Assumes AZ 'a' exists — valid for us-east-1. Adjust if using a region without this AZ.
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.prefix}-management-subnet" })
}

resource "aws_subnet" "workload" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.workload_subnet_cidr
  availability_zone = "${var.region}a" # Assumes AZ 'a' exists — valid for us-east-1. Adjust if using a region without this AZ.

  tags = merge(var.tags, { Name = "${var.prefix}-workload-subnet" })
}

# ─── Internet Gateway + Routing ──────────────────────────────────────────────
# Required for SSM Session Manager — the agent phones home to AWS endpoints
# over HTTPS (443). No inbound route is needed; SG denies all inbound traffic.

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.prefix}-igw" })
}

resource "aws_route_table" "management" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.prefix}-management-rt" })
}

resource "aws_route_table_association" "management" {
  subnet_id      = aws_subnet.management.id
  route_table_id = aws_route_table.management.id
}

# ─── Security Group: Management ──────────────────────────────────────────────
# No inbound SSH or RDP. SSM Session Manager provides shell access without
# opening any ports. Outbound 443 allows the SSM agent to reach AWS endpoints.

resource "aws_security_group" "management" {
  name        = "${var.prefix}-management-sg"
  description = "Management subnet - SSM access only, no inbound ports"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "Allow HTTPS outbound for SSM agent and package updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTP outbound for package updates"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.prefix}-management-sg" })
}

# ─── Security Group: Workload ─────────────────────────────────────────────────
# Isolated subnet. Only accepts traffic from the management subnet.

resource "aws_security_group" "workload" {
  name        = "${var.prefix}-workload-sg"
  description = "Workload subnet - inbound from management only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow all traffic from management subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.management_subnet_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.prefix}-workload-sg" })
}

# ─── Network ACL: Management ─────────────────────────────────────────────────
# Stateless layer on top of the security group. Explicitly denies inbound
# SSH/RDP from the internet as a second line of defence.

resource "aws_network_acl" "management" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = [aws_subnet.management.id]

  # Allow established return traffic (ephemeral ports)
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Deny inbound SSH from internet
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Deny inbound RDP from internet
  ingress {
    rule_no    = 210
    protocol   = "tcp"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 3389
    to_port    = 3389
  }

  # Allow all outbound
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.tags, { Name = "${var.prefix}-management-nacl" })
}
