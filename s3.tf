#############################
# Data lake key paths
#############################

variable "data_lake_bronze" {
  type    = string
  default = "data-lake/bronze"
}

variable "data_lake_silver" {
  type    = string
  default = "data-lake/silver"
}

####################################
# Sandbox playground bucket/objects
####################################

resource "aws_s3_bucket" "mls_sandbox" {
  bucket = "mls-sandbox"
}

############################
# Setup logs folder
############################

resource "aws_s3_object" "logs" {
  bucket = aws_s3_bucket.mls_sandbox.id
  key    = "logs/"
  acl    = "private"
  source = "/dev/null"
}

resource "aws_s3_object" "file_headers" {
  bucket = aws_s3_bucket.mls_sandbox.id
  key    = "data-lake/bronze/experian_quest/quest_files/2022/11/file_headers.csv"
  acl    = "private"
  source = "data/file_headers.csv"
  etag   = filemd5("data/file_headers.csv")
}

#####################
# Upload Spark code
#####################

resource "aws_s3_object" "code_credit_score_delta" {
  bucket = aws_s3_bucket.mls_sandbox.id
  key    = "code/credit_score_delta.py"
  acl    = "private"
  source = "code/credit_score_delta.py"
  etag   = filemd5("code/credit_score_delta.py")
}

resource "aws_s3_object" "code_credit_score_iceberg" {
  bucket = aws_s3_bucket.mls_sandbox.id
  key    = "code/credit_score_iceberg.py"
  acl    = "private"
  source = "code/credit_score_iceberg.py"
  etag   = filemd5("code/credit_score_iceberg.py")
}

resource "aws_s3_object" "code_scrub_pii" {
  bucket = aws_s3_bucket.mls_sandbox.id
  key    = "code/scrub_pii.py"
  acl    = "private"
  source = "code/scrub_pii.py"
  etag   = filemd5("code/scrub_pii.py")
}