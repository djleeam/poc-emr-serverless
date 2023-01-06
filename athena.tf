locals {
  athena_spark_wg_name = "athena_spark_wg"
}

resource "aws_athena_workgroup" "data_lake_wg" {
  name        = "data_lake_wg"
  description = "Data lake workgroup with Athena engine v3"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = "s3://${aws_s3_bucket.mls_sandbox.bucket}/logs/athena_query/"
    }
  }
}

resource "aws_athena_workgroup" "athena_spark_wg" {
  name        = local.athena_spark_wg_name
  description = "Athena workgroup with PySpark engine v3"

  configuration {
    execution_role                     = aws_iam_role.athena_spark_execution_role.arn
    enforce_workgroup_configuration    = false
    publish_cloudwatch_metrics_enabled = true

    engine_version {
      selected_engine_version = "PySpark engine version 3"
    }

    result_configuration {
      output_location = "s3://${aws_s3_bucket.mls_sandbox.bucket}/logs/athena_spark/"
    }
  }
}

#############################
# Athena/Spark Service Role
#############################

resource "aws_iam_role" "athena_spark_execution_role" {
  name = "athena-spark-execution-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "athena.amazonaws.com"
        },
        "Action" : "sts:AssumeRole",
        "Condition" : {
          "StringEquals" : {
            "aws:SourceAccount" : data.aws_caller_identity.current.account_id
          },
          "ArnLike" : {
            "aws:SourceArn" : "arn:aws:athena:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workgroup/${local.athena_spark_wg_name}"
          }
        }
      }
    ]
  })
}

#############################
# Athena/Spark role policy
#############################

resource "aws_iam_policy" "athena_spark_role_policy" {
  name        = "athena-spark-role-policy"
  description = "This policy will be used for Athena Spark workgroups."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetObject"
        ],
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.mls_sandbox.id}/*",
          "arn:aws:s3:::${aws_s3_bucket.mls_sandbox.id}"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "athena:GetWorkGroup",
          "athena:TerminateSession",
          "athena:GetSession",
          "athena:GetSessionStatus",
          "athena:ListSessions",
          "athena:StartCalculationExecution",
          "athena:GetCalculationExecutionCode",
          "athena:StopCalculationExecution",
          "athena:ListCalculationExecutions",
          "athena:GetCalculationExecution",
          "athena:GetCalculationExecutionStatus",
          "athena:ListExecutors",
          "athena:ExportNotebook",
          "athena:UpdateNotebook"
        ],
        "Resource" : "arn:aws:athena:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workgroup/${local.athena_spark_wg_name}"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:CreateLogGroup",
          "logs:PutLogEvents"
        ],
        "Resource" : [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-athena:*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-athena*:log-stream:*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : "logs:DescribeLogGroups",
        "Resource" : "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "cloudwatch:PutMetricData"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "cloudwatch:namespace" : "AmazonAthenaForApacheSpark"
          }
        }
      }
    ]
  })
}

#######################################
# Athena/Spark role policy attachment
#######################################

resource "aws_iam_role_policy_attachment" "athena_spark_role_policy_attachment" {
  role       = aws_iam_role.athena_spark_execution_role.name
  policy_arn = aws_iam_policy.athena_spark_role_policy.arn
}

###########################
# Athena/Glue role policy
###########################

resource "aws_iam_policy" "athena_glue_role_policy" {
  name        = "athena-glue-role-policy"
  description = "This policy will be used for Athena Spark workgroups."

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "GlueReadDatabases",
            "Effect": "Allow",
            "Action": [
                "glue:GetDatabases"
            ],
            "Resource": "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
            "Sid": "GlueReadDatabase",
            "Effect": "Allow",
            "Action": [
                "glue:GetDatabase",
                "glue:GetTable",
                "glue:GetTables",
                "glue:GetPartition",
                "glue:GetPartitions"
            ],
            "Resource": [
                "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
                "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/data_lake_silver",
                "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/data_lake_silver/*",
                "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/default"
            ]
        },
        {
            "Sid": "GlueCreateUpdateTable",
            "Effect": "Allow",
            "Action": [
                "glue:CreateTable",
                "glue:UpdateTable",
                "glue:BatchCreatePartition"
            ],
            "Resource": [
                "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
                "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/data_lake_silver",
                "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/data_lake_silver/*"
            ]
        }
    ]
}
EOF
}

#######################################
# Athena/Glue role policy attachment
#######################################

resource "aws_iam_role_policy_attachment" "athena_glue_role_policy_attachment" {
  role       = aws_iam_role.athena_spark_execution_role.name
  policy_arn = aws_iam_policy.athena_glue_role_policy.arn
}