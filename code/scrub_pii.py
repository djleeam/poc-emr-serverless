import sys

from pyspark.sql import SparkSession

spark = (
    SparkSession.builder.getOrCreate()
)


def main(argv):
    print("Reading CSV file from S3...")

    # Read new data passed in via argv
    df = spark.read.csv(argv[1], header=True, inferSchema=True)

    cols = (
        "First Name",
        "Middle Initial",
        "Last Name",
        "Address",
        "City",
        "State",
        "Zip Code",
        "Social Security Number",
        "Date of Birth"
    )

    df = df.drop(*cols)
    df.printSchema()

    df.write.option("header", "true").csv(argv[1].replace(".csv", "-nopii"))


if __name__ == "__main__":
    main(sys.argv)
