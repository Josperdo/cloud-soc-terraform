variable "instance_name" {
  description = "Name tag and resource name prefix for the EC2 instance."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to launch the instance into."
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group to attach to the instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "admin_ssh_public_key" {
  description = "SSH RSA public key registered as an EC2 key pair. Primary access is SSM Session Manager — no inbound SSH port is opened regardless."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^ssh-rsa ", var.admin_ssh_public_key))
    error_message = "admin_ssh_public_key must be a valid SSH RSA public key starting with 'ssh-rsa '."
  }
}

variable "tags" {
  description = "Tags to apply to all compute resources."
  type        = map(string)
  default     = {}
}
