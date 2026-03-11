variable "aws_region" {
  description = "AWS region for EKS cluster"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "hrms-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
  default     = "hrms-ng-2"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_disk_size" {
  description = "Disk size for worker nodes in GB"
  type        = number
  default     = 20
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "learning"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}
