environment  = "prod"
aws_region   = "ap-south-1"
offline_plan = true # plan-only review mode; set to false for a real apply

# network
azs                  = ["ap-south-1a", "ap-south-1b"]
vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
single_nat_gateway   = false # one NAT per AZ: survives an AZ outage

# ECS / Fargate sizing
container_image    = "nginx:1.27-alpine"
container_port     = 80
task_cpu           = 1024
task_memory        = 2048
desired_count      = 3
log_retention_days = 90

# RDS sizing & safety
db_name                  = "hotel_bookings"
db_username              = "hotel_admin"
db_instance_class        = "db.m6g.large"
db_allocated_storage     = 100
db_max_allocated_storage = 500
db_multi_az              = true
db_backup_retention_days = 35
deletion_protection      = true
