# Remote state for DEV. Create the bucket + lock table once, out of band.
# For a credential-less review see scripts/tf-review.sh (swaps in a local backend).
terraform {
  backend "s3" {
    bucket         = "hotelbook-tfstate-dev"
    key            = "envs/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "hotelbook-tfstate-lock-dev"
    encrypt        = true
  }
}
