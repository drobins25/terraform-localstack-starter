terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    # For zipping Lambda code
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
  # Keep state on disk while learning
  backend "local" {}
}

provider "aws" {
  region                      = "us-east-1"

  # LocalStack wiring
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true

  endpoints {
    s3            = "http://localhost:4566"
    dynamodb      = "http://localhost:4566"
    sqs           = "http://localhost:4566"
    sns           = "http://localhost:4566"
    lambda        = "http://localhost:4566"
    apigateway    = "http://localhost:4566"
    events        = "http://localhost:4566"
    ssm           = "http://localhost:4566"
    secretsmanager= "http://localhost:4566"
    logs          = "http://localhost:4566"
    cloudwatch    = "http://localhost:4566"
    iam           = "http://localhost:4566"
    sts           = "http://localhost:4566"
  }
}