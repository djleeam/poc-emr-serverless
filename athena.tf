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

resource "aws_athena_workgroup" "analytics_spark_wg" {
  name        = "analytics_spark_wg"
  description = "Analytics workgroup with PySpark engine v3"

  configuration {
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
  name               = "athena-spark-execution-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "athena.amazonaws.com"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "aws:SourceAccount": "${data.aws_caller_identity.current.account_id}"
                },
                "ArnLike": {
                    "aws:SourceArn": "arn:aws:athena:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workgroup/${aws_athena_workgroup.analytics_spark_wg.name}"
                }
            }
        }
    ]
}
EOF
}

#############################
# Athena/Spark role policy
#############################

resource "aws_iam_policy" "athena_spark_role_policy" {
  name        = "athena-spark-role-policy"
  description = "This policy will be used for Athena Spark workgroups."

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.mls_sandbox.id}/*",
                "arn:aws:s3:::${aws_s3_bucket.mls_sandbox.id}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
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
            "Resource": "arn:aws:athena:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workgroup/${aws_athena_workgroup.analytics_spark_wg.name}"
        },
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:DescribeLogStreams",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-athena:*",
                "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-athena*:log-stream:*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "logs:DescribeLogGroups",
            "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
        },
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "cloudwatch:namespace": "AmazonAthenaForApacheSpark"
                }
            }
        }
    ]
}
EOF
}

#######################################
# Athena/Spark role policy attachment
#######################################

resource "aws_iam_role_policy_attachment" "athena_spark_role_policy_attachment" {
  role       = aws_iam_role.athena_spark_execution_role.name
  policy_arn = aws_iam_policy.athena_spark_role_policy.arn
}