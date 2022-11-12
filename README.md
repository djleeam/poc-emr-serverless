# EMR Serverless

## Submit Job: credit_score_delta.py
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

## Submit Job: credit_score_iceberg.py
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