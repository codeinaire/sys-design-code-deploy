terraform {
  backend "s3" {
    bucket         = "iq1-code-deploy-terraform-state-bucket-03bfc72f"
    key            = "infra/terraform.tfstate"
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

# Current region data (used for API Gateway Lambda integration URIs)
data "aws_region" "current" {}

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
  local_existing_package = "${path.root}/../../src/lambda_build_worker.zip"

  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.global_builds_bucket.s3_bucket_arn,
          "${module.global_builds_bucket.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

module "lambda_replication_worker" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.0.1"

  function_name         = "replication-worker"
  handler              = "index.handler"
  runtime              = "nodejs20.x"
  create_package       = false
  local_existing_package = "${path.root}/../../src/lambda_replication_worker.zip"

  environment_variables = {
    STEP_FUNCTION_ARN = aws_sfn_state_machine.file_copy_workflow.arn
  }

  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:CopyObject"
        ]
        Resource = [
          module.global_builds_bucket.s3_bucket_arn,
          "${module.global_builds_bucket.s3_bucket_arn}/*",
          module.region_a_builds_bucket.s3_bucket_arn,
          "${module.region_a_builds_bucket.s3_bucket_arn}/*",
          module.region_b_builds_bucket.s3_bucket_arn,
          "${module.region_b_builds_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.file_copy_tracking.arn
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.file_copy_workflow.arn
      }
    ]
  })
}

module "lambda_regional_sync" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.0.1"

  function_name         = "regional-sync"
  handler              = "index.handler"
  runtime              = "nodejs20.x"
  create_package       = false
  local_existing_package = "${path.root}/../../src/lambda_regional_sync.zip"

  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [

      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.global_builds_bucket.s3_bucket_arn,
          "${module.global_builds_bucket.s3_bucket_arn}/*",
          module.region_a_builds_bucket.s3_bucket_arn,
          "${module.region_a_builds_bucket.s3_bucket_arn}/*",
          module.region_b_builds_bucket.s3_bucket_arn,
          "${module.region_b_builds_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.file_copy_tracking.arn
      }
    ]
  })
}

# S3 event trigger for replication worker
resource "aws_s3_bucket_notification" "global_builds_notification" {
  bucket = module.global_builds_bucket.s3_bucket_id

  lambda_function {
    lambda_function_arn = module.lambda_replication_worker.lambda_function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".zip"
  }

  depends_on = [module.lambda_replication_worker]
}

module "lambda_step_function_invoker" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.0.1"

  function_name         = "step-function-invoker"
  handler              = "index.handler"
  runtime              = "nodejs20.x"
  create_package       = false
  local_existing_package = "${path.root}/../../src/lambda_step_function_invoker.zip"

  environment_variables = {
    STEP_FUNCTION_ARN = aws_sfn_state_machine.file_copy_workflow.arn
  }

  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.file_copy_workflow.arn
      }
    ]
  })
}

module "api_gateway" {
  source = "cloudposse/api-gateway/aws"
  version = "0.9.0"

  name    = "code-deploy-api"
  stage   = "dev"

  # Define REST API via OpenAPI with Lambda proxy integrations
  openapi_config = {
    openapi = "3.0.1"
    info = {
      title   = "code-deploy-api"
      version = "1.0"
    }
    paths = {
      "/build" = {
        post = {
          x-amazon-apigateway-integration = {
            httpMethod = "POST"
            type       = "aws_proxy"
            uri        = "arn:aws:apigateway:${data.aws_region.current.id}:lambda:path/2015-03-31/functions/${module.lambda_build_worker.lambda_function_arn}/invocations"
          }
        }
      }
      "/deploy" = {
        post = {
          x-amazon-apigateway-integration = {
            httpMethod = "POST"
            type       = "aws_proxy"
            uri        = "arn:aws:apigateway:${data.aws_region.current.id}:lambda:path/2015-03-31/functions/${module.lambda_replication_worker.lambda_function_arn}/invocations"
          }
        }
      }
    }
  }

  logging_level      = "INFO"
  metrics_enabled    = false
  data_trace_enabled = false

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# Allow API Gateway to invoke Lambdas
resource "aws_lambda_permission" "allow_apigw_invoke_build" {
  statement_id  = "AllowAPIGatewayInvokeBuild"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_build_worker.lambda_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.execution_arn}/*/POST/build"
}

resource "aws_lambda_permission" "allow_apigw_invoke_replication" {
  statement_id  = "AllowAPIGatewayInvokeReplication"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_replication_worker.lambda_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.execution_arn}/*/POST/deploy"
}

# SNS Topic for file copy failure notifications
resource "aws_sns_topic" "file_copy_failures" {
  name = "file-copy-failures"
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = "step-functions-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Step Functions to access S3, DynamoDB, and SNS
resource "aws_iam_role_policy" "step_functions_policy" {
  name = "step-functions-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:CopyObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.global_builds_bucket.s3_bucket_arn,
          "${module.global_builds_bucket.s3_bucket_arn}/*",
          module.region_a_builds_bucket.s3_bucket_arn,
          "${module.region_a_builds_bucket.s3_bucket_arn}/*",
          module.region_b_builds_bucket.s3_bucket_arn,
          "${module.region_b_builds_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.file_copy_tracking.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.file_copy_failures.arn
      }
    ]
  })
}

# DynamoDB table for file copy tracking
resource "aws_dynamodb_table" "file_copy_tracking" {
  name           = "FileCopyTracking"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "fileKey"
  range_key      = "sourceBucket"

  attribute {
    name = "fileKey"
    type = "S"
  }

  attribute {
    name = "sourceBucket"
    type = "S"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# Step Function definition
resource "aws_sfn_state_machine" "file_copy_workflow" {
  name     = "file-copy-workflow"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = templatefile("${path.module}/step_function_definition.json", {
    table_name = aws_dynamodb_table.file_copy_tracking.name
    topic_arn  = aws_sns_topic.file_copy_failures.arn
  })

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
