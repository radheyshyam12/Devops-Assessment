variable "project" {
  type    = string
  default = "hotelbook"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "aws_region" {
  type = string
}

variable "offline_plan" {
  description = "true = skip AWS credential/account lookups so `terraform plan -refresh=false` works without an AWS account."
  type        = bool
  default     = true
}

# ---- network
variable "azs" {
  type = list(string)
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "single_nat_gateway" {
  type = bool
}

# ---- ECS / Fargate
variable "container_image" {
  type = string
}

variable "container_port" {
  type    = number
  default = 80
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "log_retention_days" {
  type = number
}

# ---- RDS
variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_max_allocated_storage" {
  type = number
}

variable "db_multi_az" {
  type = bool
}

variable "db_backup_retention_days" {
  type = number
}

variable "deletion_protection" {
  description = "Applied to RDS and the ALB."
  type        = bool
}
