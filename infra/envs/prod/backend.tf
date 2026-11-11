# Remote state for PROD. Create the bucket + lock table once, out of band.
# For a credential-less review see scripts/tf-review.sh (swaps in a local backend).
terraform {
  backend "s3" {
    bucket         = "hotelbook-tfstate-prod"
    key            = "envs/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "hotelbook-tfstate-lock-prod"
    encrypt        = true
  }
}
