from pyspark.sql import SparkSession
from pyspark.sql.functions import col
from pyspark.sql.functions import to_date

BUCKET_BRONZE = "s3a://liem-sandbox/data-lake/bronze/"

spark = (
    SparkSession.builder
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
    .config("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.glue_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog")
    .config("spark.sql.catalog.glue_catalog.warehouse", "s3://liem-sandbox/data-lake/silver/")
    .config("hive.metastore.client.factory.class", "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory")
    .getOrCreate()
)

print("Reading CSV file from S3...")

df0 = spark.read.csv(
    f'{BUCKET_BRONZE}/experian_quest/test.csv', header=True, inferSchema=True
) \
    .withColumn("TRADE_DATE", to_date(col("TRADE_DATE"), "yyyyMMdd"))

# select and rename columns
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
