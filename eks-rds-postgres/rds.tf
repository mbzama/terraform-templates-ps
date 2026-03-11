# RDS Subnet Group - Uses same VPC as EKS cluster
# Public subnets used for public accessibility
resource "aws_db_subnet_group" "main" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name        = "${var.cluster_name}-db-subnet-group"
    Environment = var.environment
  }
}

# Security Group for RDS - Uses same VPC as EKS cluster
resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id # Same VPC as EKS cluster

  # Allow PostgreSQL from anywhere (public access)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "PostgreSQL from anywhere"
  }

  # Allow MySQL from anywhere (if using MySQL)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MySQL from anywhere"
  }

  # Allow from EKS cluster security group
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
    description     = "PostgreSQL from EKS cluster"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-rds-sg"
    Environment = var.environment
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "main" {
  name   = "${var.cluster_name}-db-params"
  family = var.db_engine == "postgres" ? "postgres16" : "mysql8.0"

  tags = {
    Name        = "${var.cluster_name}-db-params"
    Environment = var.environment
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.cluster_name}-db"
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  # Storage configuration
  allocated_storage     = var.db_allocated_storage
  storage_type          = var.db_storage_type
  storage_encrypted     = false
  max_allocated_storage = 0 # Disable storage autoscaling

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.db_publicly_accessible
  multi_az               = var.db_multi_az

  # Backup configuration
  backup_retention_period   = var.db_backup_retention_period
  backup_window             = "03:00-04:00"
  maintenance_window        = "mon:04:00-mon:05:00"
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.cluster_name}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Monitoring configuration
  enabled_cloudwatch_logs_exports = []
  performance_insights_enabled    = false
  monitoring_interval             = 0 # Disable enhanced monitoring

  # Additional configuration
  parameter_group_name       = aws_db_parameter_group.main.name
  deletion_protection        = var.db_deletion_protection
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.cluster_name}-db"
    Environment = var.environment
    Application = "HRMS"
    Type        = "dev-test"
  }
}
