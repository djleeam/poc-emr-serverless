resource "aws_athena_workgroup" "data_lake_wg" {
  name = "data_lake_wg"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = "s3://${aws_s3_bucket.mls_sandbox.bucket}/logs/athena/"
    }
  }
}