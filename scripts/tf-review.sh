#!/usr/bin/env bash
# Credential-less Terraform review: fmt -> init -> validate -> plan -refresh=false.
# Swaps the S3 backend for a temporary local one so no AWS account is needed.
# Usage: ./scripts/tf-review.sh [dev|prod]
set -euo pipefail
ENV="${1:-dev}"
cd "$(dirname "$0")/../infra"

terraform fmt -check -recursive -diff

cd "envs/${ENV}"
trap 'rm -f backend_override.tf' EXIT
cat > backend_override.tf <<'TF'
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
TF

terraform init -input=false -reconfigure
terraform validate
terraform plan -refresh=false -input=false
