from pyspark.sql import SparkSession
from pyspark.sql.functions import col
from pyspark.sql.functions import to_date

spark = (
    SparkSession.builder
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.0.0")
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
    .getOrCreate()
)

from delta.tables import *

BUCKET_BRONZE = "s3a://liem-sandbox/data-lake/bronze/"
BUCKET_SILVER = "s3a://liem-sandbox/data-lake/silver/"
TABLE_NAME = "credit_score_delta"

print("Reading CSV file from S3...")

df0 = spark.read.csv(
    f'{BUCKET_BRONZE}/experian_quest//quest_files/2022/10/*.csv', header=True, inferSchema=True
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

print("Writing credit score dataset as a delta table...")

df.write.format("delta") \
    .mode("overwrite") \
    .partitionBy("TRADE_DATE") \
    .save(f'{BUCKET_SILVER}/{TABLE_NAME}')

deltaTable = DeltaTable.forPath(spark, f'{BUCKET_SILVER}/{TABLE_NAME}')
deltaTable.generate("symlink_format_manifest")

print("Checking if everything is ok")

(
    spark.read.format("delta")
    .load(f'{BUCKET_SILVER}/{TABLE_NAME}')
    .where("vantage_v3_score > 700")
    .show()
)