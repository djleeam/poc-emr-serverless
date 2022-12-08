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

############################
# Setup source data
############################

resource "aws_s3_object" "data_file_headers" {
  bucket = aws_s3_bucket.mls_sandbox.id
  key    = "data-lake/bronze/experian_quest/quest_files/2022/11/file_headers.csv"
  acl    = "private"
  source = "data/file_headers.csv"
  etag   = filemd5("data/file_headers.csv")
}

resource "aws_s3_object" "data_green_tripdata" {
  bucket = aws_s3_bucket.mls_sandbox.id
  key    = "data-lake/bronze/nyc-tlc/green_tripdata_2020-04.parquet"
  acl    = "private"
  source = "data/green_tripdata_2020-04.parquet"
  etag   = filemd5("data/green_tripdata_2020-04.parquet")
}

#####################
# PySpark artifacts
#####################

#resource "aws_s3_object" "artifacts_pyspark_ge" {
#  bucket = aws_s3_bucket.mls_sandbox.id
#  key    = "artifacts/pyspark_ge.tar.gz"
#  acl    = "private"
#  source = "artifacts/pyspark_ge.tar.gz"
#  etag   = filemd5("artifacts/pyspark_ge.tar.gz")
#}

#resource "aws_s3_object" "artifacts_pyspark_db" {
#  bucket = aws_s3_bucket.mls_sandbox.id
#  key    = "artifacts/pyspark_db.tar.gz"
#  acl    = "private"
#  source = "artifacts/pyspark_db.tar.gz"
#  etag   = filemd5("artifacts/pyspark_db.tar.gz")
#}

#####################
# PySpark resources
#####################

resource "aws_s3_object" "code_credit_score_delta" {
  bucket = aws_s3_bucket.mls_sandbox.id
  key    = "code/credit_score_delta.py"
  acl    = "private"
  source = "code/credit_score_delta.py"
  etag   = filemd5("code/credit_score_delta.py")
}

resource "aws_s3_object" "code_credit_score_delta_to_postgres" {
  bucket = aws_s3_bucket.mls_sandbox.id
  key    = "code/credit_score_delta_to_postgres.py"
  acl    = "private"
  source = "code/credit_score_delta_to_postgres.py"
  etag   = filemd5("code/credit_score_delta_to_postgres.py")
}

resource "aws_s3_object" "code_ge_profile" {
  bucket = aws_s3_bucket.mls_sandbox.id
  key    = "code/ge_profile.py"
  acl    = "private"
  source = "code/ge_profile.py"
  etag   = filemd5("code/ge_profile.py")
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

#################################################
# Policy to allow S3 access to specific buckets
#################################################

resource "aws_iam_policy" "s3_access_rw" {
  name        = "S3Access"
  description = "Allows S3 access for specific buckets"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ReadFromOutputAndInputBuckets",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.mls_sandbox.id}",
                "arn:aws:s3:::${aws_s3_bucket.mls_sandbox.id}/*"
            ]
        },
        {
            "Sid": "WriteToOutputDataBucket",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.mls_sandbox.id}/*"
            ]
        }
    ]
}
EOF
}

######################################################################
# Give EMR Serverless Job role read/write access to specific buckets
######################################################################

resource "aws_iam_role_policy_attachment" "allow_job_to_access_s3_buckets" {
  role       = aws_iam_role.emr_serverless_job_role.name
  policy_arn = aws_iam_policy.s3_access_rw.arn
}