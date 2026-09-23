"""
Beginner-friendly PySpark smoke test.

Run it two ways:

  1) Locally inside spark-client (no cluster involved):
       python3 python/test_spark.py

  2) On the real Spark standalone cluster:
       spark-submit --master spark://spark-master:7077 /workspace/python/test_spark.py

When no --master is passed to spark-submit and the script itself doesn't call
.master(...), Spark defaults to local[*] — handy for a quick sanity check
without touching the cluster at all.
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col


def main():
    spark = SparkSession.builder.appName("TestSparkPython").getOrCreate()

    print(f"\n>>> Spark version: {spark.version}\n")

    # 1. Create a small DataFrame ------------------------------------------------
    data = [
        ("Alice", 29, "Paris"),
        ("Bob", 35, "London"),
        ("Charlie", 22, "Paris"),
        ("Diana", 41, "Berlin"),
        ("Ethan", 27, "London"),
    ]
    columns = ["name", "age", "city"]
    df = spark.createDataFrame(data, columns)

    print(">>> Initial DataFrame:")
    df.show()

    # 2. Transformation: filter ---------------------------------------------------
    filtered_df = df.filter(col("age") > 25)
    print(">>> Filtered DataFrame (age > 25):")
    filtered_df.show()

    # 3. Transformation: select ----------------------------------------------------
    selected_df = filtered_df.select("name", "city")
    print(">>> Selected columns (name, city):")
    selected_df.show()

    # 4. Transformation: groupBy ---------------------------------------------------
    grouped_df = df.groupBy("city").count()
    print(">>> Count of people per city:")
    grouped_df.show()

    # 5. Action: count() — this is what actually triggers execution ---------------
    total_count = df.count()
    print(f">>> Total number of records (action result): {total_count}\n")

    spark.stop()
    print(">>> SparkSession stopped. Done.")


if __name__ == "__main__":
    main()
