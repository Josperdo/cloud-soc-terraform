output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "instance_name" {
  description = "Name of the EC2 instance."
  value       = aws_instance.this.tags["Name"]
}

output "private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address of the EC2 instance. Required for outbound internet access (SSM agent, package updates) since no NAT Gateway is used. No inbound ports are open."
  value       = aws_instance.this.public_ip
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the instance."
  value       = aws_iam_role.ec2.arn
}
