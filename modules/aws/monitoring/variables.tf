variable "prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "enable_threat_detection" {
  description = "Set to true to enable GuardDuty and Security Hub. Requires a fully activated AWS account (credit card verified). Both services have a 30-day free trial."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Days to retain logs in CloudWatch Log Groups and S3. Keeps storage costs bounded."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all monitoring resources."
  type        = map(string)
  default     = {}
}
