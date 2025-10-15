# Parameter Store: simple, non-sensitive config
resource "aws_ssm_parameter" "app_env" {
  name  = "/shop/dev/APP_ENV"
  type  = "String"
  value = "local"
}

# Secrets Manager: sensitive values
resource "aws_secretsmanager_secret" "db_password" {
  name = "shop/dev/DB_PASSWORD"
}

resource "aws_secretsmanager_secret_version" "db_password_v1" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = "p@ssw0rd123" # demo value; in real life, create via CLI/console/CI
}

output "ssm_app_env_name" {
  value = aws_ssm_parameter.app_env.name
}

output "secret_db_password_name" {
  value = aws_secretsmanager_secret.db_password.name
}
