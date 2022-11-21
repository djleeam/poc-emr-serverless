import datetime
import sys

from great_expectations.dataset.sparkdf_dataset import SparkDFDataset
from great_expectations.profile.basic_dataset_profiler import BasicDatasetProfiler
from great_expectations.render.renderer import *
from great_expectations.render.view import DefaultJinjaPageView
from pyspark.sql import SparkSession


def main(argv):
    """
        Usage: ge-profile <s3_output_path.html>
    """
    spark = SparkSession \
        .builder \
        .appName("GEProfiler") \
        .getOrCreate()

    if len(sys.argv) != 3:
        print("Invalid arguments, please supply <s3_output_path.html>")
        sys.exit(1)

    # Read some trip data
    df = spark.read.parquet(argv[1], header=True)
    df.show()

    # Now profile it with Great Expectations and write the results to S3
    # When the job finishes, it will write a part-00000 file out to `output_path'
    # Copy and view the output as html
    expectation_suite, validation_result = BasicDatasetProfiler.profile(SparkDFDataset(df.limit(1000)))
    document_model = ProfilingResultsPageRenderer().render(validation_result)
    html = DefaultJinjaPageView().render(document_model)
    spark.sparkContext.parallelize([html]).coalesce(1).saveAsTextFile(f"{argv[2]}/{datetime.datetime.now()}")

if __name__ == "__main__":
    main(sys.argv)