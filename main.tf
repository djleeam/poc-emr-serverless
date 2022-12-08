provider "aws" {
  region  = "us-east-2"
  profile = "ntc.sand.1"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}