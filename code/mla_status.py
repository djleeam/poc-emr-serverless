import sys

import pyspark.sql.utils
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

DATA_SRC = sys.argv[1]
DATA_DST = sys.argv[2]
TABLE_NAME = "mla_status"

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
    lst = ["36*", "37*", "38*", "39*", "40*"]

    for x in lst:
        try:
            # Read new data passed in via argv
            df = spark.read.json(f'{DATA_SRC}/{x}')

            df = df.select(
                (F.col("timestamp") / 1000).cast("timestamp").alias("request_time"),
                "external_entity_id",
                "formatted.snapshot_id",
                "formatted_responses.`LexisNexis RiskView`.data.alert_codes",
                "formatted_responses.`LexisNexis RiskView`.data.all_reason_codes",
                "formatted_responses.`LexisNexis RiskView`.data.score_codes"
            )

            # convert array values to comma separated strings
            df = df.withColumn("request_date", F.to_date("request_time"))
            df = df.withColumn('alert_codes', F.concat_ws(',', 'alert_codes'))
            df = df.withColumn('all_reason_codes', F.concat_ws(',', 'all_reason_codes'))
            df = df.withColumn('score_codes', F.concat_ws(',', 'score_codes'))

            df.show()
            df.printSchema()

            spark.sql("use data_lake_silver")
            spark.sql("show tables").show()

            df.write.mode('overwrite') \
                .partitionBy('request_date') \
                .format("parquet") \
                .option("path", f'{DATA_DST}/{TABLE_NAME}') \
                .saveAsTable(TABLE_NAME)

            spark.sql(f"select * from {TABLE_NAME}").show()
        except pyspark.sql.utils.AnalysisException:
            print(x)

if __name__ == "__main__":
    main()
