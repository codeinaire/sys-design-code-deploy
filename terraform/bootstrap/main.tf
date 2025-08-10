terraform {
  backend "s3" {
    bucket         = "iq1-code-deploy-terraform-state-bucket-6ab8c37e"
    key            = "bootstrap/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    force_path_style = true
    endpoints = { s3 = "http://localhost:4566" }
    encrypt        = true
  }
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    dynamodb       = "http://localhost:4566"
    s3             = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  resource_prefix = "iq1-code-deploy"
}

module "terraform_state_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.2.0"

  bucket = "${local.resource_prefix}-terraform-state-bucket-${random_id.bucket_suffix.hex}"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
}
