provider "aws" {
  region  = "us-east-2"
  profile = "ntc.sand.1"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

###########################################
# Allows EMR Serverless to assume a role.
###########################################

data "aws_iam_policy_document" "allow_emr_serverless_to_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["emr-serverless.amazonaws.com"]
    }
  }
}

#####################################################
# Role to let the EMR Serverless Job assume a role.
#####################################################

resource "aws_iam_role" "emr_serverless_job_role" {
  name               = "emr-serverless-job-role"
  assume_role_policy = data.aws_iam_policy_document.allow_emr_serverless_to_assume_role.json
}

###################################################################
# Policy to allow read and write access to the Glue Data Catalog
###################################################################

resource "aws_iam_policy" "glue_access_rw" {
  name        = "GlueAccess"
  description = "Allows read and write access to the Glue Data Catalog"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "GlueCreateAndReadDataCatalog",
        "Effect": "Allow",
        "Action": [
            "glue:BatchCreatePartition",
            "glue:GetDatabase",
            "glue:GetPartition",
            "glue:CreateTable",
            "glue:GetTables",
            "glue:GetPartitions",
            "glue:CreateDatabase",
            "glue:UpdateTable",
            "glue:CreatePartition",
            "glue:GetDatabases",
            "glue:GetUserDefinedFunctions",
            "glue:GetTable"
        ],
        "Resource": ["*"]
      }
    ]
}
EOF
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

##############################
# Policy to allow RDS access
##############################

resource "aws_iam_policy" "rds_access_rw" {
  name        = "RDSAccess"
  description = "Allows RDS access"

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Action": [
             "rds-db:connect"
         ],
         "Resource": [
             "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.creditscore.resource_id}/emr_job"
         ]
      }
   ]
}
EOF
}

###################################################################
# Give EMR Serverless Job role read/write access to Glue Catalog
###################################################################

resource "aws_iam_role_policy_attachment" "allow_job_to_access_glue_catalog" {
  role       = aws_iam_role.emr_serverless_job_role.name
  policy_arn = aws_iam_policy.glue_access_rw.arn
}

######################################################################
# Give EMR Serverless Job role read/write access to specific buckets
######################################################################

resource "aws_iam_role_policy_attachment" "allow_job_to_access_s3_buckets" {
  role       = aws_iam_role.emr_serverless_job_role.name
  policy_arn = aws_iam_policy.s3_access_rw.arn
}

######################################################################
# Give EMR Serverless Job role read/write access to RDS
######################################################################

resource "aws_iam_role_policy_attachment" "allow_job_to_access_rds" {
  role       = aws_iam_role.emr_serverless_job_role.name
  policy_arn = aws_iam_policy.rds_access_rw.arn
}