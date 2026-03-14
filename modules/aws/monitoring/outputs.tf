output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector. Empty string if enable_threat_detection is false."
  value       = var.enable_threat_detection ? aws_guardduty_detector.this[0].id : ""
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = aws_cloudtrail.this.arn
}

output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket storing CloudTrail logs."
  value       = aws_s3_bucket.cloudtrail.id
}

output "ssm_sessions_log_group_name" {
  description = "CloudWatch Log Group name for SSM session logs. Passed to the bastion module."
  value       = aws_cloudwatch_log_group.ssm_sessions.name
}

output "dashboard_url" {
  description = "URL to the CloudWatch SOC dashboard."
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.soc.dashboard_name}"
}
