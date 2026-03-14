output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "management_subnet_id" {
  description = "ID of the management subnet."
  value       = aws_subnet.management.id
}

output "workload_subnet_id" {
  description = "ID of the workload subnet."
  value       = aws_subnet.workload.id
}

output "management_sg_id" {
  description = "ID of the management security group."
  value       = aws_security_group.management.id
}

output "workload_sg_id" {
  description = "ID of the workload security group."
  value       = aws_security_group.workload.id
}
