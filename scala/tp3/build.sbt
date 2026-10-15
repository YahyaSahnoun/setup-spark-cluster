ThisBuild / scalaVersion := "2.12.18"   // must match the Spark 3.5.3 build
ThisBuild / version      := "0.1.0"

lazy val root = (project in file("."))
  .settings(
    name := "tp3-spark-mysql",
    libraryDependencies ++= Seq(
      // "provided": already present in $SPARK_HOME/jars inside the containers
      "org.apache.spark" %% "spark-sql"        % "3.5.3"  % "provided",
      "com.mysql"         % "mysql-connector-j" % "8.0.33" % "provided"
    )
  )
