# ─── Placement ───────────────────────────────────────────────────────────────

variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Short prefix prepended to every resource name (lowercase, 2-6 chars)."
  type        = string
  default     = "soc"

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.prefix))
    error_message = "prefix must be 2-6 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Environment tag applied to all resources."
  type        = string
  default     = "lab"
}

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = {}
}

# ─── Network ─────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "management_subnet_cidr" {
  description = "CIDR for the management subnet (public, SSM access)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "workload_subnet_cidr" {
  description = "CIDR for the workload subnet (private, isolated)."
  type        = string
  default     = "10.0.2.0/24"
}

# ─── Compute ─────────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "EC2 instance type. t3.micro is Free Tier eligible (750 hrs/month, 12 months)."
  type        = string
  default     = "t3.micro"
}

variable "admin_ssh_public_key" {
  description = "SSH RSA public key registered as an EC2 key pair (fallback access — primary access is SSM)."
  type        = string
  sensitive   = true
}

# ─── Monitoring ──────────────────────────────────────────────────────────────

variable "enable_threat_detection" {
  description = "Set to true to enable GuardDuty and Security Hub. Requires a fully activated AWS account."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Days to retain logs in CloudWatch Log Groups and S3. Keeps storage costs bounded."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 3653
    error_message = "log_retention_days must be between 1 and 3653."
  }
}
