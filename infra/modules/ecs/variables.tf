variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Subnets for the ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Subnets for the Fargate tasks."
  type        = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "ecs_security_group_id" {
  type = string
}

variable "container_image" {
  description = "Any simple image, e.g. nginx:1.27-alpine or a placeholder backend."
  type        = string
}

variable "container_port" {
  type    = number
  default = 80
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "cpu" {
  description = "Fargate task CPU units (256, 512, 1024, ...)."
  type        = number
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
}

variable "desired_count" {
  type = number
}

variable "environment_variables" {
  description = "Plain (non-secret) env vars for the container."
  type        = map(string)
  default     = {}
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN holding the DB credentials; injected as DB_PASSWORD."
  type        = string
}

variable "log_retention_days" {
  type = number
}

variable "deletion_protection" {
  description = "Applied to the ALB."
  type        = bool
}

variable "tags" {
  type    = map(string)
  default = {}
}
