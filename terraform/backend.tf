# IMPORTANT — local state is git-ignored by terraform/.gitignore, but it is still
# stored on disk in plain text. Until this backend block is activated the state
# file is not encrypted, not versioned, and not shared safely with teammates.
#
# REQUIRED before team use or any sensitive resource is managed:
#   1. Run `terraform init && terraform apply` without this backend (creates infra).
#   2. Provision a dedicated S3 bucket + DynamoDB table for Terraform state
#      (separate from the site bucket — use a bootstrap script or a separate root module).
#   3. Fill in the values below, uncomment the block, then run:
#        terraform init -migrate-state
#
# terraform {
#   backend "s3" {
#     bucket         = "<your-state-bucket-name>"
#     key            = "portfolio-site/terraform.tfstate"
#     region         = "ap-south-1"
#     dynamodb_table = "<your-lock-table-name>"
#     encrypt        = true
#   }
# }
