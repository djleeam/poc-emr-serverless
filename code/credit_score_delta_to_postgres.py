import sys

import boto3
from pyspark.sql import SparkSession

REGION = "us-east-2"
DB_NAME = "postgres"
DB_PORT = 5432
DB_USER = "emr_job"

BUCKET_SILVER = "s3a://mls-sandbox/data-lake/silver"
TABLE_NAME = "credit_score_delta"

spark = (
    SparkSession.builder
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.0.0")
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
    .config("spark.sql.catalog.glue_catalog.warehouse", "s3://mls-sandbox/data-lake/silver/")
    .config("hive.metastore.client.factory.class",
            "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory")
    .enableHiveSupport()
    .getOrCreate()
)


def main(argv):
    db_endpoint = argv[1]
    trade_date = argv[2]

    client = boto3.client('rds', region_name=REGION)
    token = client.generate_db_auth_token(db_endpoint, DB_PORT, DB_USER)

    print(f"DB auth token: {token}")

    df = spark.read.format("delta") \
        .load(f'{BUCKET_SILVER}/{TABLE_NAME}') \
        .where(f"trade_date = '{trade_date}'")

    df.show()

    df.write.format('jdbc').options(
        url=f"jdbc:postgresql://{db_endpoint}:{DB_PORT}/{DB_NAME}",
        driver="org.postgresql.Driver",
        dbtable=TABLE_NAME,
        user=DB_USER,
        password=token
    ).mode("overwrite").save()


if __name__ == "__main__":
    main(sys.argv)
