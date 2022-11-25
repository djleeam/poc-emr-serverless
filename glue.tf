######################
# Data Lake Database
######################

resource "aws_glue_catalog_database" "data_lake_silver" {
  name = "data_lake_silver"
}

#####################################
# Credit Score (Delta table format)
#####################################

resource "aws_glue_catalog_table" "credit_score_delta" {
  name          = "credit_score_delta"
  database_name = aws_glue_catalog_database.data_lake_silver.name
  owner         = "hadoop"
  parameters = {
    "EXTERNAL"              = "TRUE"
    "transient_lastDdlTime" = "1668232110"
  }
  table_type = "EXTERNAL_TABLE"

  partition_keys {
    name = "trade_date"
    type = "date"
  }
  storage_descriptor {
    bucket_columns            = []
    compressed                = false
    input_format              = "org.apache.hadoop.hive.ql.io.SymlinkTextInputFormat"
    location                  = "s3://${aws_s3_bucket.mls_sandbox.id}/${var.data_lake_silver}/credit_score_delta/_symlink_format_manifest"
    number_of_buckets         = -1
    output_format             = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    parameters                = {}
    stored_as_sub_directories = false

    columns {
      name       = "member_uuid"
      parameters = {}
      type       = "string"
    }
    columns {
      name       = "vantage_v3_score"
      parameters = {}
      type       = "int"
    }

    ser_de_info {
      parameters = {
        "serialization.format" = "1"
      }
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }
  }
}