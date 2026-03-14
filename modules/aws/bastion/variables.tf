variable "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name to ship SSM session logs to. Created by the monitoring module."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all bastion resources."
  type        = map(string)
  default     = {}
}
