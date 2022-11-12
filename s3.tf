#############################
# Sandbox playground bucket
#############################

resource "aws_s3_bucket" "liem_sandbox" {
  bucket = "liem-sandbox"

  tags = {
    Account     = "ntc.sand.1"
    Env         = "ntc.sand"
    Environment = "ntc.sand"
  }
}


############################
# Setup logs folder
############################

resource "aws_s3_object" "logs" {
  bucket = aws_s3_bucket.liem_sandbox.id
  key    = "logs/"
  acl    = "private"
  source = "/dev/null"
}

############################
# Setup data lake folders
############################

resource "aws_s3_object" "data_lake_bronze" {
  bucket = aws_s3_bucket.liem_sandbox.id
  key    = "data-lake/bronze/"
  acl    = "private"
  source = "/dev/null"
}

resource "aws_s3_object" "data_lake_silver" {
  bucket = aws_s3_bucket.liem_sandbox.id
  key    = "data-lake/silver/"
  acl    = "private"
  source = "/dev/null"
}

#####################
# Upload Spark code
#####################

resource "aws_s3_object" "code_credit_score_delta" {
  bucket = aws_s3_bucket.liem_sandbox.id
  key    = "code/credit_score_delta.py"
  acl    = "private"
  source = "code/credit_score_delta.py"
  etag   = filemd5("code/credit_score_delta.py")
}

resource "aws_s3_object" "code_credit_score_iceberg" {
  bucket = aws_s3_bucket.liem_sandbox.id
  key    = "code/credit_score_iceberg.py"
  acl    = "private"
  source = "code/credit_score_iceberg.py"
  etag   = filemd5("code/credit_score_iceberg.py")
}