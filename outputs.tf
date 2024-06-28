output "secret_id" {
  description = "The ID of the secret"
  value       = aws_secretsmanager_secret.credentials.id
}

output "secret_version_id" {
  description = "The secret ID of the secret version"
  value       = aws_secretsmanager_secret_version.secret_version.secret_id
}
