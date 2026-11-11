terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Plan-only review mode: no AWS account or credentials needed.
  # Set offline_plan = false (and use real credentials) for an actual deployment.
  access_key                  = var.offline_plan ? "mock-access-key" : null
  secret_key                  = var.offline_plan ? "mock-secret-key" : null
  skip_credentials_validation = var.offline_plan
  skip_requesting_account_id  = var.offline_plan
  skip_metadata_api_check     = var.offline_plan

  default_tags {
    tags = local.tags
  }
}
