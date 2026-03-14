# ─── Network ─────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "management_subnet_id" {
  description = "ID of the management subnet."
  value       = module.network.management_subnet_id
}

output "workload_subnet_id" {
  description = "ID of the workload subnet."
  value       = module.network.workload_subnet_id
}

# ─── Compute ─────────────────────────────────────────────────────────────────

output "instance_id" {
  description = "ID of the EC2 workload instance."
  value       = module.compute.instance_id
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = module.compute.private_ip
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the EC2 instance."
  value       = module.compute.iam_role_arn
}

# ─── Bastion ─────────────────────────────────────────────────────────────────

output "ssm_session_document" {
  description = "Name of the SSM Session Manager preferences document."
  value       = module.bastion.session_document_name
}

# ─── Monitoring ──────────────────────────────────────────────────────────────

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector."
  value       = module.monitoring.guardduty_detector_id
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = module.monitoring.cloudtrail_arn
}

output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket storing CloudTrail logs."
  value       = module.monitoring.cloudtrail_bucket_name
}

output "soc_dashboard_url" {
  description = "URL to the CloudWatch SOC dashboard."
  value       = module.monitoring.dashboard_url
}

# ─── SSM Connect Helper ───────────────────────────────────────────────────────
# Print the exact command needed to start an SSM session after deploy.

output "ssm_connect_command" {
  description = "AWS CLI command to connect to the workload instance via SSM Session Manager."
  value       = "aws ssm start-session --target ${module.compute.instance_id} --region ${var.region}"
}
