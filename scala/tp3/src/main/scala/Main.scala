import org.apache.spark.sql.{SparkSession, DataFrame}
import org.apache.spark.sql.functions._
import java.util.Properties

object Main {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder().appName("TP3").getOrCreate()
    import spark.implicits._

    val url = "jdbc:mysql://mysql:3306/classicmodels?useSSL=false&allowPublicKeyRetrieval=true"
    val props = new Properties()
    props.put("user", "root"); props.put("password", "root")
    props.put("driver", "com.mysql.cj.jdbc.Driver")

    // Items 4-5: customers DataFrame and show
    val customers    = spark.read.jdbc(url, "customers", props)
    val orders       = spark.read.jdbc(url, "orders", props)
    val orderdetails = spark.read.jdbc(url, "orderdetails", props)
    customers.show()

    // Needed for the SQL versions
    customers.createOrReplaceTempView("customers")
    orders.createOrReplaceTempView("orders")
    orderdetails.createOrReplaceTempView("orderdetails")

    // ... steps 2-4 go here
    // Op 1: customers per state
    customers.groupBy("state").count().show()
    spark.sql("SELECT state, COUNT(*) AS nb FROM customers GROUP BY state").show()

    // Op 2: max / min of the prices of purchased products
    orderdetails.agg(max("priceEach"), min("priceEach")).show()
    spark.sql("SELECT MAX(priceEach), MIN(priceEach) FROM orderdetails").show()

    // Op 3: all customers + their order ids (even without orders) -> LEFT JOIN
    customers.join(orders, Seq("customerNumber"), "left")
    .select("customerName", "orderNumber").show()
    spark.sql("""SELECT c.customerName, o.orderNumber FROM customers c
                LEFT JOIN orders o ON c.customerNumber = o.customerNumber""").show()

    // Op 4: New York customers with no orders -> LEFT ANTI JOIN
    customers.filter($"state" === "NY")
    .join(orders, Seq("customerNumber"), "left_anti")
    .select("customerNumber", "customerName", "city", "state").show()
    spark.sql("""SELECT customerNumber, customerName, city, state FROM customers c
                WHERE state = 'NY' AND NOT EXISTS
                (SELECT 1 FROM orders o WHERE o.customerNumber = c.customerNumber)""").show()
    spark.stop()
  }
}