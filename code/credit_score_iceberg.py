import sys

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

DATA_SRC = sys.argv[1]
DATA_DST = sys.argv[2]
TABLE_NAME = "credit_score_iceberg"

spark = (
    SparkSession.builder
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
    .config("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.glue_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog")
    .config("spark.sql.catalog.glue_catalog.warehouse", f"{DATA_DST}")
    .config("hive.metastore.client.factory.class",
            "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory")
    .getOrCreate()
)


def main():
    print("Reading CSV file from S3...")

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

    print("Writing credit score dataset as an Iceberg table...")

    # Create Iceberg table if it does not exist
    spark.sql(f"""CREATE TABLE IF NOT EXISTS glue_catalog.data_lake_silver.credit_score_iceberg (
    member_uuid string,
    vantage_v3_score int,
    trade_date date)
    USING iceberg
    PARTITIONED BY (trade_date)
    LOCATION '{DATA_DST}/{TABLE_NAME}'""")

    # Create temp view for dataframe and perform MERGE INTO operation
    df.createOrReplaceTempView("credit_score_df")
    spark.sql("""MERGE INTO glue_catalog.data_lake_silver.credit_score_iceberg t
    USING (SELECT * FROM credit_score_df) s
    ON t.member_uuid = s.member_uuid AND t.trade_date = s.trade_date
    WHEN MATCHED THEN UPDATE SET t.vantage_v3_score = s.vantage_v3_score
    WHEN NOT MATCHED THEN INSERT (member_uuid, vantage_v3_score, trade_date)
    VALUES (s.member_uuid, s.vantage_v3_score, s.trade_date)""")

    print("Checking if everything is ok...")

    spark.sql("SELECT * FROM glue_catalog.data_lake_silver.credit_score_iceberg where vantage_v3_score > 700;").show()


if __name__ == "__main__":
    main()
