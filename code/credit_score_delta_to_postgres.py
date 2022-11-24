import sys

import boto3
import psycopg2
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

db_endpoint = sys.argv[1]
client = boto3.client('rds', region_name=REGION)
token = client.generate_db_auth_token(db_endpoint, DB_PORT, DB_USER)

# Broadcast psql connection parameters to each partition
connection_props = {"host": db_endpoint, "user": DB_USER, "password": token, "database": DB_NAME}
brConnect = spark.sparkContext.broadcast(connection_props)


def process_row(row, curs_merge):
    # Get column values from dataframe row
    member_uuid = row.__getitem__("member_uuid")
    vantage_v3_score = row.__getitem__("vantage_v3_score")
    trade_date = row.__getitem__("trade_date")

    # Construct and execute upsert for each row of data
    sql_str = f"""INSERT INTO public.credit_score_delta (member_uuid, vantage_v3_score, trade_date)
    VALUES ('{member_uuid}', '{vantage_v3_score}', '{trade_date}')
    ON CONFLICT (member_uuid, trade_date)
    DO UPDATE SET member_uuid='{member_uuid}', vantage_v3_score='{vantage_v3_score}', trade_date='{trade_date}'
    """
    curs_merge.execute(sql_str)


def process_partition(partition):
    # Get broadcasted connection properties
    connection_properties = brConnect.value

    database = connection_properties.get("database");
    user = connection_properties.get("user")
    pwd = connection_properties.get("password")
    host = connection_properties.get("host")

    db_conn = psycopg2.connect(
        host=host,
        user=user,
        password=pwd,
        database=database
    )

    dbc_merge = db_conn.cursor()

    for row in partition:
        process_row(row, dbc_merge)

    db_conn.commit()
    dbc_merge.close()
    db_conn.close()

def main(argv):
    trade_date = argv[2]

    print(f"DB auth token: {token}")

    # Get data from Delta Lake for given trade_date
    df = spark.read.format("delta") \
        .load(f'{BUCKET_SILVER}/{TABLE_NAME}') \
        .where(f"trade_date = '{trade_date}'")

    df.show()

    # Reduce the number of partitions in the dataframe and process each accordingly
    df.rdd.coalesce(10).foreachPartition(process_partition)


if __name__ == "__main__":
    main(sys.argv)
