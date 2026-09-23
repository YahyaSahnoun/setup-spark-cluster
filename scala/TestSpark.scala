// Beginner-friendly Scala Spark smoke test.
//
// This file has NO package declaration on purpose, so the compiled class is
// simply named `TestSpark` (see README section 11 for the exact compile +
// spark-submit commands).

import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._

object TestSpark extends App {

  val spark = SparkSession.builder()
    .appName("TestSparkScala")
    .getOrCreate()

  println(s"\n>>> Spark version: ${spark.version}\n")

  import spark.implicits._

  // 1. Create a small DataFrame ------------------------------------------------
  val data = Seq(
    ("Alice", 29, "Paris"),
    ("Bob", 35, "London"),
    ("Charlie", 22, "Paris"),
    ("Diana", 41, "Berlin"),
    ("Ethan", 27, "London")
  )
  val df = data.toDF("name", "age", "city")

  println(">>> Initial DataFrame:")
  df.show()

  // 2. Transformation: filter ---------------------------------------------------
  val filtered = df.filter($"age" > 25)
  println(">>> Filtered DataFrame (age > 25):")
  filtered.show()

  // 3. Transformation: select ----------------------------------------------------
  val selected = filtered.select("name", "city")
  println(">>> Selected columns (name, city):")
  selected.show()

  // 4. Transformation: groupBy ---------------------------------------------------
  val grouped = df.groupBy("city").count()
  println(">>> Count of people per city:")
  grouped.show()

  // 5. Action: count() — this is what actually triggers execution ---------------
  val totalCount = df.count()
  println(s">>> Total number of records (action result): $totalCount\n")

  spark.stop()
  println(">>> SparkSession stopped. Done.")
}
