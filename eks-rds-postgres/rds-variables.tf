# RDS Database Variables
variable "db_engine" {
  description = "Database engine type"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "16.6"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the database to create"
  type        = string
  default     = "hrmsdb"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "hrmsadmin"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_storage_type" {
  description = "Storage type for RDS"
  type        = string
  default     = "gp2"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "db_publicly_accessible" {
  description = "Make database publicly accessible"
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 0
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when deleting"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}
