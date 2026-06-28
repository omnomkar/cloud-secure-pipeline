terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Created by running `bootstrap/` first. Replace the two placeholders
  # below with the `state_bucket_name` and `dynamodb_table_name` outputs
  # from that step, then run `terraform init` here.
  backend "s3" {
  bucket         = "omkar-tfstate-0001"
  key            = "secure-cloud-pipeline/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-locks"
  encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
