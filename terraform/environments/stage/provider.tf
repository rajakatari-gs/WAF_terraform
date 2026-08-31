terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # ── Remote State Backend ──────────────────────────────────
  # Each environment uses its own isolated state file.
  # Replace <YOUR_S3_BUCKET> and <YOUR_DYNAMODB_TABLE> with
  # your actual bucket and lock table names.
  backend "s3" {
    bucket         = "<YOUR_S3_BUCKET>"
    key            = "waf/stage/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "<YOUR_DYNAMODB_TABLE>"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Environment = "stage"
    }
  }
}
