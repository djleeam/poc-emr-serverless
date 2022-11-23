import sys

import boto3
import certifi
import psycopg2
from pyspark.sql import SparkSession

REGION = "us-east-2"
DB_NAME = "postgres"
DB_PORT = 5432
DB_USER = "emr_job"

BUCKET_SILVER = "s3a://mls-sandbox/data-lake/silver/"
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

    client = boto3.client('rds', region_name=REGION)
    token = client.generate_db_auth_token(db_endpoint, DB_PORT, DB_USER)

    print(f"DB auth token: {token}")

    try:
        conn = psycopg2.connect(
            host=db_endpoint,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=token,
            sslmode="verify-ca",
            sslrootcert=certifi.where()
        )
        cur = conn.cursor()
        cur.execute("""SELECT now()""")
        query_results = cur.fetchall()
        print(query_results)
    except Exception as e:
        print("Database connection failed due to {}".format(e))

    # df = spark.read.format("delta").load(f'{BUCKET_SILVER}/{TABLE_NAME}')


if __name__ == "__main__":
    main(sys.argv)
