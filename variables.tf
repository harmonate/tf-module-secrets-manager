variable "secret_name" {
  description = "The name of the secret to create"
  type        = string
}

variable "secret_type" {
  description = "Type of secret (cognito, rds, or none)"
  type        = string
  validation {
    condition     = contains(["cognito", "rds", "none"], var.secret_type)
    error_message = "Secret type must be 'cognito', 'rds', or 'none'."
  }
}

variable "username" {
  description = "The username to store in the secret"
  type        = string
}

variable "rotation_days" {
  description = "Whether to enable rotation of the secret"
  type        = number
}

variable "cognito_user_pool_arn" {
  description = "The ARN of the Cognito User Pool to attach the secret to"
  type        = string
  default     = null
}

variable "rds_db_instance_arn" {
  description = "The ARN of the RDS instance to attach the secret to"
  type        = string
  default     = null
}

variable "only_rotate_secret" {
  description = "Whether to only rotate the secret"
  type        = bool
  default     = false
}
