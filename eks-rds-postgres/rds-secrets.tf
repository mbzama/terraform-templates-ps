# Generate random password for RDS
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store RDS credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "rds_credentials" {
  name        = "${var.cluster_name}-rds-credentials"
  description = "RDS database credentials for ${var.cluster_name}"

  tags = {
    Name        = "${var.cluster_name}-rds-credentials"
    Environment = var.environment
    Application = "HRMS"
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = var.db_engine
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    endpoint = aws_db_instance.main.endpoint
  })
}
