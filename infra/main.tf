terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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
    apigateway     = "http://localhost:4566"
    apigatewayv2   = "http://localhost:4566"
    cloudformation = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    logs           = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    es             = "http://localhost:4566"
    elasticache    = "http://localhost:4566"
    firehose       = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kinesis        = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    rds            = "http://localhost:4566"
    redshift       = "http://localhost:4566"
    route53        = "http://localhost:4566"
    s3             = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    ses            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    ssm            = "http://localhost:4566"
    stepfunctions  = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}

module "sqs_build_jobs_queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "5.0.0"


  name       = "build-jobs-queue"
  fifo_queue = true
  create_dlq = true
  dlq_name   = "build-jobs-queue-dlq"
}

module "sqs_deployment_jobs_queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "5.0.0"


  name       = "deployment-jobs-queue"
  fifo_queue = true
  create_dlq = true
  dlq_name   = "deployment-jobs-queue-dlq"
}

module "global_builds_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.2.0"

  bucket = "global-builds"
}

module "region_a_builds_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.2.0"

  bucket = "region-a-builds"
}

module "region_b_builds_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.2.0"

  bucket = "region-b-builds"
}


module "dynamodb_replication_status_table" {
  source = "terraform-aws-modules/dynamodb-table/aws"

  name     = "replication-status"
  hash_key = "build_id"
  attributes = [
    {
      name = "build_id"
      type = "S"
    }
  ]
}

module "dynamodb_tables" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "5.0.0"

  name     = "host-deployment-logs"
  hash_key = "log_id"
  attributes = [
    {
      name = "log_id"
      type = "S"
    }
  ]
}

module "lambda_build_worker" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.0.1"

  function_name         = "build-worker"
  handler              = "index.handler"
  runtime              = "nodejs20.x"
  create_package       = false
  local_existing_package = "../src/lambda_build_worker.zip"
}

module "lambda_replication_worker" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.0.1"

  function_name         = "replication-worker"
  handler              = "index.handler"
  runtime              = "nodejs20.x"
  create_package       = false
  local_existing_package = "../src/lambda_replication_worker.zip"
}

module "lambda_regional_sync" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.0.1"

  function_name         = "regional-sync"
  handler              = "index.handler"
  runtime              = "nodejs20.x"
  create_package       = false
  local_existing_package = "../src/lambda_regional_sync.zip"
}
