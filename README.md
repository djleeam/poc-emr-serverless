# POC: EMR Serverless

This sandbox POC sets up the necessary roles and resources to allow the submission
of EMR Serverless jobs that process Experian quest data and persist it into two
data lake tables; one in the [Delta Lake](https://docs.delta.io/latest/delta-intro.html) table format and the other
in the [Iceberg](https://iceberg.apache.org/docs/latest/) table format.

Glue catalog tables are also created for each table respectively that then allows for the
querying of the data lake data from Athena.

## Athena/Glue

Glue table resources were imported into TF after being manually created with the following DDL in Athena.

### Create `credit_score_delta` table
```
CREATE EXTERNAL TABLE credit_score_delta (
    member_uuid STRING,
    vantage_v3_score INT
)
PARTITIONED BY (trade_date DATE)
ROW FORMAT SERDE 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe' 
STORED AS INPUTFORMAT 'org.apache.hadoop.hive.ql.io.SymlinkTextInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat' 
LOCATION 's3://${S3_BUCKET}/data-lake/silver/credit_score_delta/_symlink_format_manifest/';
```

### Create `credit_score_iceberg` table
```
CREATE TABLE IF NOT EXISTS glue_catalog.data_lake_silver.credit_score_iceberg (
    member_uuid string,
    vantage_v3_score int,
    trade_date date)
PARTITIONED BY (month(trade_date))
LOCATION 's3://${S3_BUCKET}/data-lake/silver/credit_score_iceberg'
TBLPROPERTIES ('table_type' = 'ICEBERG');
```

## EMR Serverless

### Build a virtualenv archive for dependencies

All the commands below should be executed in the `/artifacts` directory. The command builds the included Dockerfile
and exports the resulting Python virtualenv file to your local filesystem.

```
# Build python venv with `great_expectations` deps
DOCKER_BUILDKIT=1 docker build -f Dockerfile-ge --output . .

# Build python venv with DB deps
DOCKER_BUILDKIT=1 docker build -f Dockerfile-db --output . .
```

### Setting environment vars for job runs

Make sure to set the following variables according to your environment and specific job run.

```
export S3_BUCKET=<YOUR_S3_BUCKET_NAME>
export APPLICATION_ID=<EMR_SERVERLESS_APPLICATION_ID>
export JOB_ROLE_ARN=<EMR_SERVERLESS_IAM_ROLE>
export RDS_ENDPOINT=<RDS_ENDPOINT>
```

### Creating necessary tables and roles for RDS related jobs

Make sure to create the following table/user/grants for the RDS role-based IAM access to work.

```
CREATE TABLE credit_score_delta (
    member_uuid VARCHAR,
    vantage_v3_score INT,
    trade_date DATE
);

CREATE USER emr_job WITH LOGIN;
GRANT rds_iam to emr_job;
GRANT ALL ON TABLE public.credit_score_delta TO emr_job;
ALTER TABLE public.credit_score_delta OWNER TO emr_job;
```

### Job: ge_profile.py
```
JOB_RUN_ID=`aws emr-serverless start-job-run \
    --name "GE Profile" \
    --application-id $APPLICATION_ID \
    --execution-role-arn $JOB_ROLE_ARN \
    --job-driver '{
        "sparkSubmit": {
            "entryPoint": "s3://'${S3_BUCKET}'/code/ge_profile.py",
            "entryPointArguments": ["s3://'${S3_BUCKET}'/data-lake/bronze/nyc-tlc/green_tripdata_2020-04.parquet", "s3://'${S3_BUCKET}'/logs/ge-profile"],
            "sparkSubmitParameters": "--conf spark.archives=s3://'${S3_BUCKET}'/artifacts/pyspark_ge.tar.gz#environment --conf spark.emr-serverless.driverEnv.PYSPARK_DRIVER_PYTHON=./environment/bin/python --conf spark.emr-serverless.driverEnv.PYSPARK_PYTHON=./environment/bin/python --conf spark.emr-serverless.executorEnv.PYSPARK_PYTHON=./environment/bin/python"
        }
    }' \
    --configuration-overrides '{
        "monitoringConfiguration": {
            "s3MonitoringConfiguration": {
                "logUri": "s3://'${S3_BUCKET}'/logs/emr_serverless"
            }
        }
    }' --profile ntc.sand.1 | jq -r '.jobRunId?'` && export JOB_RUN_ID
```

### Job: scrub_pii.py
```
JOB_RUN_ID=`aws emr-serverless start-job-run \
    --name "Scrub PII" \
    --application-id $APPLICATION_ID \
    --execution-role-arn $JOB_ROLE_ARN \
    --job-driver '{
        "sparkSubmit": {
            "entryPoint": "s3://'${S3_BUCKET}'/code/scrub_pii.py",
            "entryPointArguments": ["s3://'${S3_BUCKET}'/data-lake/bronze/experian_quest/quest_files/2022/10/experian-2022-10-16.csv"]
        }
    }' \
    --configuration-overrides '{
        "monitoringConfiguration": {
            "s3MonitoringConfiguration": {
                "logUri": "s3://'${S3_BUCKET}'/logs/emr_serverless"
            }
        }
    }' --profile ntc.sand.1 | jq -r '.jobRunId?'` && export JOB_RUN_ID
```

### Job: credit_score_delta.py
```
JOB_RUN_ID=`aws emr-serverless start-job-run \
    --name "Credit Score Delta Lake" \
    --application-id $APPLICATION_ID \
    --execution-role-arn $JOB_ROLE_ARN \
    --job-driver '{
        "sparkSubmit": {
            "entryPoint": "s3://'${S3_BUCKET}'/code/credit_score_delta.py",
            "entryPointArguments": ["s3://'${S3_BUCKET}'/data-lake/bronze/experian_quest/quest_files/2022/10/experian-2022-10-16-nopii"],
            "sparkSubmitParameters": "--packages io.delta:delta-core_2.12:2.1.1,software.amazon.awssdk:bundle:2.18.11,software.amazon.awssdk:url-connection-client:2.18.11"
        }
    }' \
    --configuration-overrides '{
        "monitoringConfiguration": {
            "s3MonitoringConfiguration": {
                "logUri": "s3://'${S3_BUCKET}'/logs/emr_serverless"
            }
        }
    }' --profile ntc.sand.1 | jq -r '.jobRunId?'` && export JOB_RUN_ID
```

### Job: credit_score_delta_to_postgres.py
```
JOB_RUN_ID=`aws emr-serverless start-job-run \
    --name "Credit Score Delta to Postgres" \
    --application-id $APPLICATION_ID \
    --execution-role-arn $JOB_ROLE_ARN \
    --job-driver '{
        "sparkSubmit": {
            "entryPoint": "s3://'${S3_BUCKET}'/code/credit_score_delta_to_postgres.py",
            "entryPointArguments": ["'${RDS_ENDPOINT}'", "2022-10-12"],
            "sparkSubmitParameters": "--packages io.delta:delta-core_2.12:2.1.1,org.postgresql:postgresql:42.5.0,software.amazon.awssdk:bundle:2.18.11,software.amazon.awssdk:url-connection-client:2.18.11"
        }
    }' \
    --configuration-overrides '{
        "monitoringConfiguration": {
            "s3MonitoringConfiguration": {
                "logUri": "s3://'${S3_BUCKET}'/logs/emr_serverless"
            }
        }
    }' --profile ntc.sand.1 | jq -r '.jobRunId?'` && export JOB_RUN_ID
```

### Job: credit_score_iceberg.py
```
JOB_RUN_ID=`aws emr-serverless start-job-run \
    --name "Credit Score Iceberg" \
    --application-id $APPLICATION_ID \
    --execution-role-arn $JOB_ROLE_ARN \
    --job-driver '{
        "sparkSubmit": {
            "entryPoint": "s3://'${S3_BUCKET}'/code/credit_score_iceberg.py",
            "entryPointArguments": ["s3://'${S3_BUCKET}'/data-lake/bronze/experian_quest/quest_files/2022/10/experian-2022-10-16-nopii"],
            "sparkSubmitParameters": "--packages org.apache.iceberg:iceberg-spark-runtime-3.3_2.12:1.0.0,software.amazon.awssdk:bundle:2.18.11,software.amazon.awssdk:url-connection-client:2.18.11"
        }
    }' \
    --configuration-overrides '{
        "monitoringConfiguration": {
            "s3MonitoringConfiguration": {
                "logUri": "s3://'${S3_BUCKET}'/logs/emr_serverless"
            }
        }
    }' --profile ntc.sand.1 | jq -r '.jobRunId?'` && export JOB_RUN_ID
```

## Get job stdout
```
aws s3 cp s3://${S3_BUCKET}/logs/emr_serverless/applications/$APPLICATION_ID/jobs/$JOB_RUN_ID/SPARK_DRIVER/stdout.gz - --profile ntc.sand.1 | gunzip | less
```

## Get job stderr
```
aws s3 cp s3://${S3_BUCKET}/logs/emr_serverless/applications/$APPLICATION_ID/jobs/$JOB_RUN_ID/SPARK_DRIVER/stderr.gz - --profile ntc.sand.1 | gunzip | less
```