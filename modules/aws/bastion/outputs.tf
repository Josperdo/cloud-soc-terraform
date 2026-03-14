output "session_document_name" {
  description = "Name of the SSM Session Manager preferences document."
  value       = aws_ssm_document.session_preferences.name
}

output "session_document_arn" {
  description = "ARN of the SSM Session Manager preferences document."
  value       = aws_ssm_document.session_preferences.arn
}
