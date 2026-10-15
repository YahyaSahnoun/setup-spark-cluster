# =============================================================================
# Spark Lab image — used for spark-master, spark-worker AND spark-client.
#
# Using ONE image for all three services guarantees that Java, Scala, Spark
# and PySpark are the exact same version everywhere, which is the #1 source
# of "it works in the shell but not on the cluster" bugs.
#
# Versions (checked for mutual compatibility):
#   Java     : 17 (Temurin)     -> supported by Spark 3.3+
#   Spark    : 3.5.3            -> stable 3.5.x line
#   Scala    : 2.12.18          -> Spark 3.5.x is built against Scala 2.12
#   Python   : 3.10 (Ubuntu 22.04 "jammy" default)
#   PySpark  : 3.5.3            -> pinned to match the Spark cluster version
#   Kafka    : spark-sql-kafka-0-10_2.12 3.5.3 + kafka-clients 3.4.1
#              (broker runs separately as apache/kafka:3.8.0; compatible)
# =============================================================================

FROM eclipse-temurin:17-jdk-jammy

LABEL maintainer="spark-docker-lab"

ARG SPARK_VERSION=3.5.3
ARG HADOOP_VERSION=3
ARG SCALA_VERSION=2.12.18
ARG SBT_VERSION=1.10.2
ARG MYSQL_CONNECTOR_VERSION=8.0.33
ARG KAFKA_CLIENTS_VERSION=3.4.1
ARG COMMONS_POOL2_VERSION=2.11.1

ENV SPARK_HOME=/opt/spark
ENV SCALA_HOME=/usr/local/scala
ENV PATH="${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${SCALA_HOME}/bin:${PATH}"
# Silence Python buffering so logs/prints show up immediately in `docker logs`
ENV PYTHONUNBUFFERED=1

# -----------------------------------------------------------------------------
# OS packages: only what's strictly needed (curl/wget to fetch Spark+Scala,
# python3 for PySpark, procps for jps/ps which are handy for debugging Spark).
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        wget \
        python3 \
        python3-pip \
        procps \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Scala 2.12.18 (matches the Scala version Spark 3.5.x is built with)
# -----------------------------------------------------------------------------
RUN wget -q "https://github.com/scala/scala/releases/download/v${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz" -O /tmp/scala.tgz \
    && tar -xzf /tmp/scala.tgz -C /usr/local \
    && ln -s "/usr/local/scala-${SCALA_VERSION}" "${SCALA_HOME}" \
    && rm /tmp/scala.tgz

# -----------------------------------------------------------------------------
# Apache Spark 3.5.3 (pre-built for Hadoop 3)
# -----------------------------------------------------------------------------
RUN wget -q "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" -O /tmp/spark.tgz \
    && tar -xzf /tmp/spark.tgz -C /opt \
    && mv "/opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}" "${SPARK_HOME}" \
    && rm /tmp/spark.tgz

# -----------------------------------------------------------------------------
# PySpark, pinned to the exact same version as the Spark cluster above.
# JupyterLab + ipykernel let you run .ipynb notebooks (spark-client only, but
# installing it in the shared image keeps master/worker/client identical).
# -----------------------------------------------------------------------------
RUN pip3 install --no-cache-dir \
        "pyspark==${SPARK_VERSION}" \
        jupyterlab \
        ipykernel

# -----------------------------------------------------------------------------
# MySQL JDBC driver, dropped straight into Spark's jars/ folder so that the
# driver (spark-client) AND the executors (spark-worker) can both find
# com.mysql.cj.jdbc.Driver without any --jars / --packages flag.
# -----------------------------------------------------------------------------
RUN wget -q "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar" \
        -P "${SPARK_HOME}/jars/"

# -----------------------------------------------------------------------------
# Spark <-> Kafka connector (Structured Streaming `format("kafka")`).
# Dropped into jars/ for the same reason as the MySQL driver: driver AND
# executors find it without --packages. These four jars are the exact set
# Spark 3.5.3 needs (versions taken from the spark-sql-kafka-0-10 3.5.3 POM).
# -----------------------------------------------------------------------------
RUN cd "${SPARK_HOME}/jars" \
    && wget -q "https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/${SPARK_VERSION}/spark-sql-kafka-0-10_2.12-${SPARK_VERSION}.jar" \
    && wget -q "https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.12/${SPARK_VERSION}/spark-token-provider-kafka-0-10_2.12-${SPARK_VERSION}.jar" \
    && wget -q "https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/${KAFKA_CLIENTS_VERSION}/kafka-clients-${KAFKA_CLIENTS_VERSION}.jar" \
    && wget -q "https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/${COMMONS_POOL2_VERSION}/commons-pool2-${COMMONS_POOL2_VERSION}.jar"

# -----------------------------------------------------------------------------
# sbt (for the "Scala SBT project" asked for in the TP)
# -----------------------------------------------------------------------------
RUN wget -q "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" -O /tmp/sbt.tgz \
    && tar -xzf /tmp/sbt.tgz -C /usr/local \
    && rm /tmp/sbt.tgz
ENV PATH="/usr/local/sbt/bin:${PATH}"

WORKDIR /workspace

# Default command (overridden per-service in docker-compose.yml)
CMD ["/bin/bash"]