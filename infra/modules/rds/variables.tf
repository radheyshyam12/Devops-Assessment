variable "name" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "security_group_id" {
  description = "RDS security group (ingress from ECS only)."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL version. A major-only value (e.g. \"16\") lets AWS pick the latest minor."
  type        = string
  default     = "16"
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling."
  type        = number
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_period" {
  description = "Days to keep automated backups."
  type        = number
}

variable "deletion_protection" {
  type = bool
}

variable "skip_final_snapshot" {
  type = bool
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "port" {
  type    = number
  default = 5432
}

variable "tags" {
  type    = map(string)
  default = {}
}
