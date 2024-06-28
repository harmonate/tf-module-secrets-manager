variable "secret_name" {
  description = "The name of the secret to create"
  type        = string
}

variable "min_length" {
  description = "The minimum length of the password"
  type        = number
}

variable "max_length" {
  description = "The maximum length of the password"
  type        = number
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
