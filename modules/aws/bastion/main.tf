# ─── SSM Session Manager Preferences ────────────────────────────────────────
# AWS equivalent of Azure Bastion — provides shell access to EC2 instances
# without opening any inbound ports. The instance needs only outbound 443
# and the AmazonSSMManagedInstanceCore IAM policy (set in compute module).
#
# This document configures account-wide Session Manager preferences:
#   - Session logs shipped to CloudWatch for audit trail
#   - Idle timeout to prevent orphaned sessions
#   - No S3 logging (avoids storage costs for a lab)
#   - No KMS key (uses default SSM encryption — sufficient for a lab)

resource "aws_ssm_document" "session_preferences" {
  #checkov:skip=CKV_AWS_112:SSM Session Manager encrypts sessions in transit using TLS by default. A KMS key provides additional envelope encryption which is not required for a lab.
  #checkov:skip=CKV_AWS_113:CloudWatch session logging IS enabled (cloudWatchStreamingEnabled=true). Checkov flags this because cloudWatchEncryptionEnabled=false — KMS encryption not required for a lab.
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "SOC Lab — SSM Session Manager preferences"
    sessionType   = "Standard_Stream"
    inputs = {
      # Ship session activity to CloudWatch for audit trail
      cloudWatchLogGroupName      = var.cloudwatch_log_group_name
      cloudWatchStreamingEnabled  = true
      cloudWatchEncryptionEnabled = false

      # No S3 logging — avoids storage costs for a lab environment
      s3BucketName        = ""
      s3KeyPrefix         = ""
      s3EncryptionEnabled = false

      # Session timeouts
      idleSessionTimeout = "20"
      maxSessionDuration = "60"

      # No customer-managed KMS key — SSM encrypts sessions by default
      kmsKeyId = ""

      # Do not force a specific OS user for sessions
      runAsEnabled     = false
      runAsDefaultUser = ""
    }
  })

  tags = var.tags
}
