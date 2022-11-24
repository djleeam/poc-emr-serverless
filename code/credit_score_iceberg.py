import sys

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = (
    SparkSession.builder
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
    .config("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.glue_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog")
    .config("spark.sql.catalog.glue_catalog.warehouse", "s3://mls-sandbox/data-lake/silver/")
    .config("hive.metastore.client.factory.class",
            "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory")
    .getOrCreate()
)


def main(argv):
    print("Reading CSV file from S3...")

    # Read new data passed in via argv
    df0 = spark.read.csv(argv[1], header=True, inferSchema=True) \
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

    df.write.format("iceberg") \
        .mode("overwrite") \
        .save("glue_catalog.data_lake_silver.credit_score_iceberg")

    print("Checking if everything is ok")

    spark.sql("SELECT * FROM glue_catalog.data_lake_silver.credit_score_iceberg where vantage_v3_score > 700;").show()


if __name__ == "__main__":
    main(sys.argv)
