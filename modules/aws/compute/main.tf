# ─── AMI Lookup ──────────────────────────────────────────────────────────────
# Always resolves to the latest Ubuntu 22.04 LTS HVM image from Canonical.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── IAM Role + Instance Profile ─────────────────────────────────────────────
# AWS equivalent of Azure's system-assigned Managed Identity.
# The instance profile is what gets attached to EC2 — it wraps the IAM role.

resource "aws_iam_role" "ec2" {
  name = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# SSM Session Manager — provides shell access without opening any inbound ports.
# AWS equivalent of Azure Bastion.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent — allows the agent to push logs and metrics to CloudWatch.
# AWS equivalent of the Azure Monitor Agent (AMA).
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.ec2.name
  tags = var.tags
}

# ─── SSH Key Pair ─────────────────────────────────────────────────────────────
# Registered but not usable for direct access — the security group denies all
# inbound traffic including SSH. Primary and only access method is SSM Session Manager.

resource "aws_key_pair" "this" {
  key_name   = "${var.instance_name}-key"
  public_key = var.admin_ssh_public_key
  tags       = var.tags
}

# ─── EC2 Instance ─────────────────────────────────────────────────────────────

resource "aws_instance" "this" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/cloud-init.yaml")

  metadata_options {
    # Require IMDSv2 — prevents SSRF attacks from reading instance metadata.
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(var.tags, { Name = var.instance_name })
}
