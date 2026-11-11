resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-db-subnets" })
}

resource "aws_db_instance" "this" {
  identifier = "${var.name}-pg"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  port     = var.port

  # RDS generates the password and stores it in Secrets Manager:
  # no credentials in code, tfvars or state.
  manage_master_user_password = true

  # Private only, reachable solely through the RDS security group.
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period  = var.backup_retention_period
  backup_window            = "21:00-22:00" # 02:30-03:30 IST
  maintenance_window       = "sun:22:30-sun:23:30"
  copy_tags_to_snapshot    = true
  delete_automated_backups = var.skip_final_snapshot

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-pg-final"

  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(var.tags, { Name = "${var.name}-pg" })
}
