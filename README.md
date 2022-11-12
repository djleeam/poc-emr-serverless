# ntc-sandbox

This sandbox POC sets up the necessary roles and resources to allow the submission
of EMR Serverless jobs that process Experian quest data and persist it into two
data lake tables; one in the Delta Lake table format and the other in the Iceberg table format.

Glue catalog tables are also created for each table respectively that then allows for the
querying of the data lake data from Athena.

## Athena/Glue

Glue table resources were imported into TF after being manually created with the following DDL in Athena.

### Create `credit_score_delta` table and sync manifest with `MSCK`
```
CREATE EXTERNAL TABLE credit_score_delta (
    member_uuid STRING,
    vantage_v3_score INT
)
PARTITIONED BY (trade_date DATE)
ROW FORMAT SERDE 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe' 
STORED AS INPUTFORMAT 'org.apache.hadoop.hive.ql.io.SymlinkTextInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat' 
LOCATION 's3://liem-sandbox/data-lake/silver/credit_score_delta/_symlink_format_manifest/';
```
```
MSCK REPAIR TABLE credit_score_delta;
```

### Create `credit_score_iceberg` table
```
CREATE TABLE IF NOT EXISTS glue_catalog.data_lake_silver.credit_score_iceberg (
    member_uuid string,
    vantage_v3_score int,
    trade_date date)
PARTITIONED BY (month(trade_date))
LOCATION 's3://liem-sandbox/data-lake/silver/credit_score_iceberg'
TBLPROPERTIES ('table_type' = 'ICEBERG');
```

## EMR Serverless

### Submit Job: credit_score_delta.py
```
aws emr-serverless start-job-run \
    --name "Credit Score Delta Lake" \
    --application-id $APPLICATION_ID \
    --execution-role-arn $JOB_ROLE_ARN \
    --job-driver '{
        "sparkSubmit": {
            "entryPoint": "s3://liem-sandbox/code/credit_score_delta.py",
            "sparkSubmitParameters": "--packages io.delta:delta-core_2.12:2.0.0"
        }
    }' \
    --configuration-overrides '{
        "monitoringConfiguration": {
            "s3MonitoringConfiguration": {
                "logUri": "s3://liem-sandbox/logs/"
            }
        }
    }' --profile ntc.sand.1
```

### Submit Job: credit_score_iceberg.py
```
aws emr-serverless start-job-run \
    --name "Credit Score Iceberg" \
    --application-id $APPLICATION_ID \
    --execution-role-arn $JOB_ROLE_ARN \
    --job-driver '{
        "sparkSubmit": {
            "entryPoint": "s3://liem-sandbox/code/credit_score_iceberg.py",
            "sparkSubmitParameters": "--packages org.apache.iceberg:iceberg-spark-runtime-3.3_2.12:1.0.0,software.amazon.awssdk:bundle:2.18.11,software.amazon.awssdk:url-connection-client:2.18.11"
        }
    }' \
    --configuration-overrides '{
        "monitoringConfiguration": {
            "s3MonitoringConfiguration": {
                "logUri": "s3://liem-sandbox/logs/"
            }
        }
    }' --profile ntc.sand.1
```


## Get Job stdout / stderr
```
aws s3 cp s3://liem-sandbox/logs/applications/$APPLICATION_ID/jobs/$JOB_RUN_ID/SPARK_DRIVER/stdout.gz - --profile ntc.sand.1 | gunzip
```
```
aws s3 cp s3://liem-sandbox/logs/applications/$APPLICATION_ID/jobs/$JOB_RUN_ID/SPARK_DRIVER/stderr.gz - --profile ntc.sand.1 | gunzip
```