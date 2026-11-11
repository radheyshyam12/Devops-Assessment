locals {
  name = "${var.project}-${var.environment}"

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "network" {
  source = "../../modules/network"

  name                 = local.name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  container_port       = var.container_port
  db_port              = 5432
  tags                 = local.tags
}

module "rds" {
  source = "../../modules/rds"

  name                    = local.name
  subnet_ids              = module.network.private_subnet_ids
  security_group_id       = module.network.rds_security_group_id
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_days
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = !var.deletion_protection
  db_name                 = var.db_name
  db_username             = var.db_username
  port                    = 5432
  tags                    = local.tags
}

module "ecs" {
  source = "../../modules/ecs"

  name                  = local.name
  region                = var.aws_region
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  ecs_security_group_id = module.network.ecs_security_group_id

  container_image = var.container_image
  container_port  = var.container_port
  cpu             = var.task_cpu
  memory          = var.task_memory
  desired_count   = var.desired_count

  environment_variables = {
    DB_HOST = module.rds.address
    DB_PORT = tostring(module.rds.port)
    DB_NAME = var.db_name
    DB_USER = var.db_username
  }
  db_secret_arn = module.rds.master_user_secret_arn

  log_retention_days  = var.log_retention_days
  deletion_protection = var.deletion_protection
  tags                = local.tags
}
