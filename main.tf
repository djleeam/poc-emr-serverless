terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.49.0"
    }
  }
}

provider "aws" {
  region  = "us-east-2"
  profile = "ntc.sand.1"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}