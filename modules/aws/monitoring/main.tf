# ─── Account ID Lookup ───────────────────────────────────────────────────────
# Used to construct globally unique S3 bucket names.

data "aws_caller_identity" "current" {}

# ─── CloudWatch Log Groups ────────────────────────────────────────────────────
# AWS equivalent of Log Analytics Workspace log tables.
# Retention set to 30 days on all groups — prevents storage costs accumulating
# after the lab is complete. Free Tier covers 5 GB/month ingestion + storage.

resource "aws_cloudwatch_log_group" "syslog" {
  name              = "/soc-lab/syslog"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "auth" {
  name              = "/soc-lab/auth"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "ssm_sessions" {
  name              = "/soc-lab/ssm-sessions"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/soc-lab/cloudtrail"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ─── CloudTrail ───────────────────────────────────────────────────────────────
# Records all AWS API calls (management events) for the account.
# AWS equivalent of Azure Activity Log + Diagnostic Settings.
# First trail per region is free. Management events only — data events cost money.

# S3 bucket — CloudTrail requires a bucket as its primary destination.
resource "aws_s3_bucket" "cloudtrail" {
  # Account ID suffix guarantees global uniqueness.
  bucket        = "${var.prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Allows terraform destroy to remove the bucket even if logs exist.
  tags          = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule — expire objects after log_retention_days to control S3 costs.
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "expire-cloudtrail-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }
  }
}

# Bucket policy — CloudTrail service requires explicit permission to write.
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# IAM role — allows CloudTrail to write to the CloudWatch Log Group.
resource "aws_iam_role" "cloudtrail_cw" {
  name = "${var.prefix}-cloudtrail-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cloudtrail_cw" {
  name = "${var.prefix}-cloudtrail-cw-policy"
  role = aws_iam_role.cloudtrail_cw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

resource "aws_cloudtrail" "this" {
  name                          = "${var.prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cw.arn
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  # Management events only — data events (S3 object-level, Lambda invoke) cost money.
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = var.tags

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_cloudwatch_log_group.cloudtrail
  ]
}

# ─── GuardDuty ────────────────────────────────────────────────────────────────
# AWS threat detection service. Analyzes CloudTrail, VPC Flow Logs, and DNS
# logs for malicious activity. AWS equivalent of Microsoft Sentinel detections.
# 30-day free trial — destroy before day 30 to avoid charges.

resource "aws_guardduty_detector" "this" {
  count  = var.enable_threat_detection ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = false # Disabled — S3 data event analysis costs money
    }
    kubernetes {
      audit_logs {
        enable = false # No EKS in this lab
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = false # Malware scanning costs money
        }
      }
    }
  }

  tags = var.tags
}

# ─── Security Hub ─────────────────────────────────────────────────────────────
# Aggregates findings from GuardDuty and other AWS services into a single view.
# AWS equivalent of Microsoft Defender for Cloud / Sentinel incident panel.
# 30-day free trial — destroy before day 30 to avoid charges.

resource "aws_securityhub_account" "this" {
  count = var.enable_threat_detection ? 1 : 0
}

# AWS Foundational Security Best Practices standard — free during trial.
resource "aws_securityhub_standards_subscription" "fsbp" {
  count         = var.enable_threat_detection ? 1 : 0
  standards_arn = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.this]
}

# ─── CloudWatch Dashboard ─────────────────────────────────────────────────────
# Basic SOC visibility panel. AWS equivalent of the Sentinel workbook.

resource "aws_cloudwatch_dashboard" "soc" {
  dashboard_name = "${var.prefix}-soc-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "log"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Auth Log Events"
          region  = var.region
          view    = "table"
          query   = "SOURCE '/soc-lab/auth' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Syslog — Recent Events"
          region  = var.region
          view    = "table"
          query   = "SOURCE '/soc-lab/syslog' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "SSM Session Activity"
          region  = var.region
          view    = "table"
          query   = "SOURCE '/soc-lab/ssm-sessions' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "CloudTrail — API Activity"
          region  = var.region
          view    = "table"
          query   = "SOURCE '/soc-lab/cloudtrail' | fields @timestamp, eventName, userIdentity.arn, sourceIPAddress | sort @timestamp desc | limit 50"
          period  = 300
        }
      }
    ]
  })
}
