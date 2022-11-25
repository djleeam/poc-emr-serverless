import sys

import boto3
import psycopg2
from pyspark.sql import SparkSession

DATA_SRC = sys.argv[1]
DB_HOST = sys.argv[2]
DB_USER = "emr_job"
TRADE_DATE_FILTER = sys.argv[3]
TABLE_NAME = "credit_score_delta"

spark = (
    SparkSession.builder
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.0.0")
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
    .config("spark.sql.catalog.glue_catalog.warehouse", DATA_SRC)
    .config("hive.metastore.client.factory.class",
            "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory")
    .enableHiveSupport()
    .getOrCreate()
)

client = boto3.client('rds', region_name="us-east-2")
token = client.generate_db_auth_token(DB_HOST, 5432, DB_USER)

# Broadcast psql connection parameters to each partition
connection_props = {"host": DB_HOST, "user": DB_USER, "password": token, "database": "postgres"}
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

    database = connection_properties.get("database")
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


def main():
    # Get data from Delta Lake for given trade_date
    df = spark.read.format("delta") \
        .load(f'{DATA_SRC}/{TABLE_NAME}') \
        .where(f"trade_date = '{TRADE_DATE_FILTER}'")

    df.show()

    # Reduce the number of partitions in the dataframe and process each accordingly
    df.rdd.coalesce(10).foreachPartition(process_partition)


if __name__ == "__main__":
    main()
