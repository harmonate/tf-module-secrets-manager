output "secret_id" {
  description = "The ID of the secret"
  value       = aws_secretsmanager_secret.credentials.id
}
