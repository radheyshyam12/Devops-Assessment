output "alb_dns_name" {
  description = "Public entry point (Internet -> ALB)."
  value       = module.ecs.alb_dns_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "rds_endpoint" {
  description = "Private endpoint; only reachable from the ECS security group."
  value       = module.rds.address
}

output "rds_secret_arn" {
  value = module.rds.master_user_secret_arn
}
