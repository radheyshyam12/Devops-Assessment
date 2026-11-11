variable "name" {
  description = "Name prefix for all resources (e.g. hotelbook-dev)."
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  description = "Availability zones; one public and one private subnet is created per AZ."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheap, dev). false = one NAT per AZ (HA, prod)."
  type        = bool
  default     = true
}

variable "container_port" {
  description = "Port the ECS tasks listen on (ALB -> ECS)."
  type        = number
  default     = 80
}

variable "db_port" {
  description = "Database port (ECS -> RDS)."
  type        = number
  default     = 5432
}

variable "tags" {
  type    = map(string)
  default = {}
}
