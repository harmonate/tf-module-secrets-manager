locals {
  password_requirements = {
    rds = {
      length           = 41
      special          = true
      override_special = "!#$%&*()-_=+[]{}<>:?"
    }
    cognito = {
      length           = 256
      special          = true
      override_special = "^$*.[]{}()?-\"!@#%&/\\,><':;|_~`"
    }
    none = {
      length           = 32
      special          = false
    }
  }

  selected_requirements = local.password_requirements[var.secret_type]
}

resource "random_password" "password" {
  count            = var.only_rotate_secret ? 0 : 1
  length           = local.selected_requirements.length
  special          = local.selected_requirements.special
  override_special = lookup(local.selected_requirements, "override_special", null)
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = local.selected_requirements.special ? 1 : 0
}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
  lower   = true
}

resource "aws_secretsmanager_secret" "credentials" {
  provider = aws.default
  name     = "${var.secret_name}-${random_string.suffix.result}"
}

resource "aws_secretsmanager_secret_version" "secret_version" {
  provider  = aws.default
  secret_id = aws_secretsmanager_secret.credentials.id
  secret_string = jsonencode({
    username = var.username
    password = random_password.password[0].result
  })
}

resource "aws_iam_role" "lambda_rotation" {
  provider = aws.default
  count    = var.rotation_days > 0 ? 1 : 0
  name     = "${var.secret_name}-lambda-secrets-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  provider   = aws.default
  count      = var.rotation_days > 0 ? 1 : 0
  role       = aws_iam_role.lambda_rotation[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets_manager_policy" {
  provider = aws.default
  count    = var.rotation_days > 0 ? 1 : 0
  role     = aws_iam_role.lambda_rotation[count.index].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = flatten([
      [
        {
          Action = [
            "secretsmanager:GetSecretValue",
            "secretsmanager:PutSecretValue",
            "secretsmanager:DescribeSecret",
            "secretsmanager:UpdateSecretVersionStage"
          ],
          Effect   = "Allow",
          Resource = aws_secretsmanager_secret.credentials.arn
        }
      ],
      var.cognito_user_pool_arn != null ? [
        {
          Action = [
            "cognito-idp:AdminSetUserPassword",
            "cognito-idp:AdminCreateUser",
            "cognito-idp:AdminGetUser",
            "cognito-idp:AdminUpdateUserAttributes"
          ],
          Effect   = "Allow",
          Resource = var.cognito_user_pool_arn
        }
      ] : [],
      var.rds_db_instance_arn != null ? [
        {
          Action = [
            "rds:ModifyDBInstance"
          ],
          Effect   = "Allow",
          Resource = var.rds_db_instance_arn
        }
      ] : []
    ])
  })
}


resource "aws_secretsmanager_secret_rotation" "rotation" {
  count               = var.rotation_days > 0 ? 1 : 0
  provider            = aws.default
  secret_id           = aws_secretsmanager_secret.credentials.id
  rotation_lambda_arn = aws_lambda_function.secrets_rotation_function[count.index].arn
  rotation_rules {
    automatically_after_days = var.rotation_days
  }
}

locals {
  lambda_secrets_package_path = "${path.module}/lambda_function.zip"
  fileexists_secrets          = fileexists(local.lambda_secrets_package_path)
  secrets_source_code_hash    = local.fileexists_secrets ? filebase64sha256(local.lambda_secrets_package_path) : null
}

resource "aws_lambda_function" "secrets_rotation_function" {
  provider      = aws.default
  count         = var.rotation_days > 0 ? 1 : 0
  function_name = "${var.secret_name}-secrets-rotation"
  description   = "Function to handle Secret Rotation"
  handler       = "lambda-secrets.lambda_handler"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_rotation[count.index].arn

  filename         = local.lambda_secrets_package_path
  source_code_hash = local.secrets_source_code_hash

  environment {
    variables = merge(
      var.cognito_user_pool_arn != null ? {
        USER_POOL_ID    = var.cognito_user_pool_arn
        CREDENTIAL_TYPE = "cognito"
      } : {},
      var.rds_db_instance_arn != null ? {
        RDS_INSTANCE_ARN = var.rds_db_instance_arn
        CREDENTIAL_TYPE  = "database"
      } : {},
      var.only_rotate_secret != null ? {
        ONLY_ROTATE_SECRET = var.only_rotate_secret
        CREDENTIAL_TYPE    = "rotate-only"
      } : {}
    )
  }
}

resource "aws_lambda_permission" "allow_secretsmanager" {
  provider      = aws.default
  count         = var.rotation_days > 0 ? 1 : 0
  statement_id  = "AllowSecretsManagerInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secrets_rotation_function[count.index].function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.credentials.arn
}




