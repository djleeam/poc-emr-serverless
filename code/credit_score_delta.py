import sys

from delta.tables import *
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

DATA_SRC = sys.argv[1]
DATA_DST = sys.argv[2]
TABLE_NAME = "credit_score_delta"

spark = (
    SparkSession.builder
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.0.0")
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
    .config("spark.sql.catalog.glue_catalog.warehouse", DATA_DST)
    .config("hive.metastore.client.factory.class",
            "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory")
    .enableHiveSupport()
    .getOrCreate()
)


def main():
    print("Reading CSV file from S3...")

    # Truncate table (optional)
    # df_t = spark.read.format("delta").load(f'{BUCKET_SILVER}/{TABLE_NAME}')
    # df_t.limit(0).write.mode("overwrite").format("delta").save(f'{BUCKET_SILVER}/{TABLE_NAME}')

    # Read new data passed in via argv
    df0 = spark.read.csv(DATA_SRC, header=True, inferSchema=True) \
        .withColumn("TRADE_DATE", F.to_date("TRADE_DATE", "yyyyMMdd"))

    print("Spark DataFrame shape...")
    print((df0.count(), len(df0.columns)))

    # Select and rename columns
    df = df0.select(
        "Member UUID",
        "VANTAGE_V3_SCORE",
        "TRADE_DATE"
    ) \
        .withColumnRenamed("Member UUID", "member_uuid") \
        .withColumnRenamed("VANTAGE_V3_SCORE", "vantage_v3_score") \
        .withColumnRenamed("TRADE_DATE", "trade_date")

    df.printSchema()

    # Create Delta table if it does not exist
    DeltaTable.createIfNotExists(spark) \
        .location(f'{DATA_DST}/{TABLE_NAME}') \
        .addColumns(df.schema) \
        .partitionedBy("trade_date") \
        .execute()

    print("Merge new credit score data to Delta table...")

    credit_score_delta_tbl = DeltaTable.forPath(spark, f'{DATA_DST}/{TABLE_NAME}')

    # Perform merge into Delta table with new data
    # https://docs.databricks.com/delta/merge.html#merge-operation-semantics
    credit_score_delta_tbl.alias('scores') \
        .merge(
        df.alias('new_scores'),
        'scores.member_uuid = new_scores.member_uuid AND scores.trade_date = new_scores.trade_date'
    ) \
        .whenMatchedUpdate(set=
    {
        "member_uuid": "new_scores.member_uuid",
        "trade_date": "new_scores.trade_date",
        "vantage_v3_score": "new_scores.vantage_v3_score"
    }
    ) \
        .whenNotMatchedInsert(values=
    {
        "member_uuid": "new_scores.member_uuid",
        "trade_date": "new_scores.trade_date",
        "vantage_v3_score": "new_scores.vantage_v3_score"
    }
    ) \
        .execute()

    # Update manifest
    credit_score_delta_tbl.generate("symlink_format_manifest")

    print("Row counts after merge...")
    (
        spark.read.format("delta")
        .load(f'{DATA_DST}/{TABLE_NAME}')
        .agg(F.count("*"))
        .show()
    )

    # We can query tables with SparkSQL
    # spark.sql("SHOW TABLES").show()

    # Or we can also them with native Spark code
    print(spark.catalog.listTables())


if __name__ == "__main__":
    main()
