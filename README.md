# Spark + MySQL Docker Environment

A self-contained Docker Compose lab for practicing Apache Spark with **both
PySpark and Scala**, against a real (if tiny) Spark Standalone cluster
running on your own machine, plus a **MySQL 8** database for the
DataFrame <-> MySQL exercises of **TP3** (`classicmodels`, `ENSA_DB`).

---

## 1. Overview

This project gives you four containers:

| Service        | Role                                                                    |
|----------------|--------------------------------------------------------------------------|
| `mysql`        | MySQL 8.0 with `classicmodels` and `ENSA_DB` created automatically       |
| `spark-master` | Spark Standalone Master                                                  |
| `spark-worker` | One Spark Worker, registered with the master                             |
| `spark-client` | Dev container: `sbt`, `pyspark`, `spark-shell`, `spark-submit`, `scalac`, Jupyter |

You do all your work from `spark-client`. `mysql`, `spark-master` and
`spark-worker` just need to be up and running in the background.

---

## 2. Architecture

```text
                              Host
                               │
                         Docker Compose
                               │
     ┌──────────────┬──────────┼───────────────┐
     ▼              ▼          ▼               ▼
   mysql       spark-master  spark-worker  spark-client
 (:3306 in      (UI :8080)    (UI :8081)    (UI :4040)
  network,          │             │              │
  :3307 host)       │             │       ┌──────┴──────┐
     ▲              │             │    PySpark        Scala/sbt
     │              └─────────────┴───────┬─────────────┘
     │                       spark://spark-master:7077
     └──────────── JDBC: jdbc:mysql://mysql:3306 ◄── driver + executors
```

All Spark containers share **one Docker image** (built once from the single
`Dockerfile`), so Java, Scala, Spark, PySpark and the MySQL JDBC driver are
guaranteed to be identical everywhere.

**Important:** inside the Docker network, MySQL is reachable at
`mysql:3306`, **not** `localhost:3306`. `localhost` inside a container is the
container itself. From your host machine (DBeaver, `mysql` CLI...), use
`127.0.0.1:3307`.

---

## 3. Requirements

- Pop!_OS 24.04 (or any recent Linux/macOS/Windows with Docker)
- Docker Engine + Docker Compose v2 (`docker compose`, not the old
  `docker-compose`)
- ~8 GB of free RAM for the containers (comfortable on a 16 GB machine):
  worker 3 GB + client 3 GB + MySQL 1 GB + master 1 GB (upper limits)
- Internet access the first time you build (Spark, Scala, sbt, JDBC driver)
  and the first time sbt resolves dependencies

---

## 4. Project Structure

```text
spark-docker/
│
├── docker-compose.yml
├── Dockerfile
├── README.md
│
├── mysql-init/                      # run ONCE on first MySQL start, in filename order
│   ├── 00-create-ensa-db.sql        # creates ENSA_DB (TP3 Part II)
│   └── 01-classicmodels.sql         # YOU add this (TP3 Part I) - see section 7
│
├── python/
│   └── test_spark.py
│
├── scala/
│   ├── TestSpark.scala              # standalone scalac example (section 12)
│   └── tp3/                         # sbt project for TP3
│       ├── build.sbt
│       ├── project/build.properties
│       └── src/main/scala/          # your TP3 .scala files go here
│
├── notebooks/
│   └── test_spark.ipynb
│
└── data/                            # mounted at /opt/spark-data in ALL Spark containers
    ├── .gitkeep
    └── empData.csv                  # YOU add this (TP3 Part II)
```

`data/` is mounted into the master, worker and client at `/opt/spark-data`.
The **worker needs it too**: executors read input files themselves, so a path
that only exists on the client would fail with "file not found".

---

## 5. Version Compatibility

| Component         | Version                  | Why it's compatible                                   |
|-------------------|--------------------------|--------------------------------------------------------|
| Java              | 17 (Temurin)             | Spark 3.3+ officially supports Java 17                |
| Spark             | 3.5.3                    | Stable 3.5.x release                                  |
| Scala             | 2.12.18                  | Spark 3.5.x is built against Scala 2.12               |
| sbt               | 1.10.2                   | `build.sbt` must use `scalaVersion := "2.12.18"`      |
| Python            | 3.10 (Ubuntu 22.04 base) | Within PySpark 3.5.x's supported range (3.8-3.12)     |
| PySpark           | 3.5.3 (pip)              | Pinned to match the Spark cluster version exactly     |
| MySQL server      | 8.0                      | Official image, `mysql_native_password` enabled       |
| MySQL JDBC driver | mysql-connector-j 8.0.33 | Baked into `$SPARK_HOME/jars` (driver class `com.mysql.cj.jdbc.Driver`) |
| JupyterLab        | latest (pip)             | Only needs a compatible Python                        |

Keeping PySpark's pip version identical to the cluster's Spark version is the
single most important compatibility rule here: a mismatch is the #1 cause
of cryptic `spark-submit` errors.

---

## 6. Setup

```bash
# from inside the spark-docker/ directory
docker compose build
```

This builds the shared image (`spark-lab:3.5.3`) once. The first build takes
a few minutes (downloading Spark, Scala, sbt and the JDBC driver); later
builds are cached.

---

## 7. Prepare the TP3 Data

1. **classicmodels**: download the `classicmodels` SQL script (the
   mysqltutorial.org one) and save it as:

   ```text
   mysql-init/01-classicmodels.sql
   ```

   The script already contains `CREATE DATABASE classicmodels` / `USE`, and
   MySQL runs the files in `mysql-init/` alphabetically, so `ENSA_DB` is
   created first and `classicmodels` second.

2. **empData.csv**: put it in `data/`.

> Init scripts only run on the **first** start with an **empty** MySQL
> volume. If you add or change a script later, re-run them with:
> `docker compose down -v && docker compose up -d` (this deletes all MySQL data).

---

## 8. Start the Environment

```bash
docker compose up -d
docker compose ps
```

You should see `mysql`, `spark-master`, `spark-worker` and `spark-client`
all `Up`. `mysql` shows `healthy` once the import has finished;
`spark-client` only starts after that, so the first start can take a minute.

---

## 9. Check MySQL

```bash
docker compose exec mysql mysql -uroot -proot \
  -e "SHOW DATABASES; USE classicmodels; SHOW TABLES; SELECT COUNT(*) FROM customers;"
```

You should see `classicmodels` and `ENSA_DB` in the list, 8 `classicmodels`
tables, and 122 customers.

Credentials: user `root`, password `root`.

| From where                  | Host        | Port   |
|-----------------------------|-------------|--------|
| Spark code (any container)  | `mysql`     | `3306` |
| Your host (DBeaver, CLI...) | `127.0.0.1` | `3307` |

---

## 10. Check the Spark Cluster

```bash
docker compose logs spark-worker | grep -i "registered"
```

You should see a line like:

```text
INFO Worker: Successfully registered with master spark://spark-master:7077
```

---

## 11. Access the Spark Web UI

| UI                   | URL                   | What it shows                                      |
|----------------------|-----------------------|-----------------------------------------------------|
| Spark Master UI      | http://localhost:8080 | Registered workers, running/completed applications  |
| Spark Worker UI      | http://localhost:8081 | That worker's cores, memory, running executors      |
| Spark Application UI | http://localhost:4040 | Jobs/stages/tasks for the app *currently* running   |

Open http://localhost:8080 first: under "Workers" you should see one worker
listed as `ALIVE`. The Application UI at port 4040 only exists **while a job
is actively running**.

---

## 12. Test PySpark and Scala

Enter the client container:

```bash
docker compose exec spark-client bash
```

### 12.1 Interactive shells

```bash
pyspark     --master spark://spark-master:7077
spark-shell --master spark://spark-master:7077
```

The **driver** runs inside `spark-client`; the **executors** are launched by
`spark-worker`. Try `spark.range(1000).count()`. Exit with `exit()` /
`:quit`.

### 12.2 PySpark script

```bash
python3 python/test_spark.py                       # local sanity check
spark-submit --master spark://spark-master:7077 /workspace/python/test_spark.py
```

### 12.3 Scala with plain `scalac` (quick single-file tests)

```bash
cd /workspace/scala
mkdir -p build/classes
scalac -classpath "$SPARK_HOME/jars/*" -d build/classes TestSpark.scala
cd build/classes && jar cf ../TestSpark.jar . && cd ../..

spark-submit --class TestSpark --master spark://spark-master:7077 \
  /workspace/scala/build/TestSpark.jar
```

For anything bigger than one file (like TP3), use sbt (next section).

---

## 13. TP3: Spark DataFrames with MySQL (Scala + sbt)

The sbt project lives in `scala/tp3/`. Spark and the MySQL driver are marked
`provided` in `build.sbt` because they're already in `$SPARK_HOME/jars`
inside the containers, so they are **not** bundled into your JAR.

### 13.1 Connection settings (differences from the TP handout)

The handout assumes MySQL runs on your own machine. In this environment:

```scala
val url   = "jdbc:mysql://mysql:3306/classicmodels?useSSL=false&allowPublicKeyRetrieval=true"
val table = "customers"                      // the DB is already in the URL

val properties = new java.util.Properties()
properties.put("user", "root")
properties.put("password", "root")           // not ""

Class.forName("com.mysql.cj.jdbc.Driver")    // old com.mysql.jdbc.Driver is deprecated

val customersDF = sparkSession.read.jdbc(url, table, properties)
```

Do **not** hardcode `.master("local[*]")` in your `SparkSession`: let
`spark-submit --master ...` decide.

### 13.2 Part I: read from MySQL

Put your sources in `scala/tp3/src/main/scala/`, then:

```bash
cd /workspace/scala/tp3
sbt package
spark-submit \
  --class <YourMainObject> \
  --master spark://spark-master:7077 \
  target/scala-2.12/tp3-spark-mysql_2.12-0.1.0.jar
```

The first `sbt package` downloads dependencies (a few minutes); they are
cached in named Docker volumes afterwards.

### 13.3 Part II: write a CSV into MySQL

```scala
val empDF = sparkSession.read
  .option("header", "true")
  .option("inferSchema", "true")
  .csv("/opt/spark-data/empData.csv")

empDF.write
  .mode("overwrite")                       // or "append"
  .jdbc("jdbc:mysql://mysql:3306/ENSA_DB?useSSL=false&allowPublicKeyRetrieval=true",
        "employees", properties)
```

Verify from the host:

```bash
docker compose exec mysql mysql -uroot -proot -e "SELECT * FROM ENSA_DB.employees LIMIT 10;"
```

### 13.4 Quick iteration without sbt

For experiments, `spark-shell` works with no packaging at all (the driver is
already on its classpath):

```bash
spark-shell --master spark://spark-master:7077
```

---

## 14. PySpark in a Jupyter Notebook

```bash
docker compose exec spark-client bash
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root
```

Open the printed URL (with its token) in your host browser. Start each
notebook with:

```python
from pyspark.sql import SparkSession

spark = (
    SparkSession.builder
    .appName("MyNotebookApp")
    .master("spark://spark-master:7077")
    .getOrCreate()
)
```

Reading MySQL from PySpark works the same way (driver already installed):

```python
df = (spark.read.format("jdbc")
      .option("url", "jdbc:mysql://mysql:3306/classicmodels?useSSL=false&allowPublicKeyRetrieval=true")
      .option("dbtable", "customers")
      .option("user", "root").option("password", "root")
      .option("driver", "com.mysql.cj.jdbc.Driver")
      .load())
```

Call `spark.stop()` when you're done, or the executors keep holding the
worker's 2 cores / 2 GB.

---

## 15. The `data/` Directory

Mounted at `/opt/spark-data` in all Spark containers:

```python
df = spark.read.csv("/opt/spark-data/mydata.csv", header=True)
```

---

## 16. Adding Your Own Projects

- **PySpark**: drop `.py` files into `python/`; live at `/workspace/python/`.
- **Scala (single file)**: `scala/`, compile with `scalac` (section 12.3).
- **Scala (sbt project)**: create a new folder next to `scala/tp3/` with its
  own `build.sbt`, or add files to `scala/tp3/src/main/scala/`.
- Rebuild the image (`docker compose build`) only if you change the
  `Dockerfile`.

---

## 17. Stopping the Environment

```bash
docker compose down        # stops containers, KEEPS MySQL data and sbt caches
docker compose down -v     # also DELETES MySQL data and sbt caches
```

Warning: `-v` wipes the `mysql-data` volume, including tables you created in
`ENSA_DB`. On the next `up`, the `mysql-init/` scripts run again from scratch.

---

## 18. Troubleshooting

- **`Communications link failure` / `Connection refused` to MySQL**: you
  probably used `localhost` in the JDBC URL. Use `mysql:3306` inside the
  containers.
- **`No suitable driver` / `ClassNotFoundException: com.mysql...`**: rebuild
  the image (`docker compose build && docker compose up -d --force-recreate`);
  the driver is added in the Dockerfile. Use `com.mysql.cj.jdbc.Driver`.
- **`Public Key Retrieval is not allowed` / SSL errors**: add
  `?useSSL=false&allowPublicKeyRetrieval=true` to the JDBC URL.
- **`Unknown database 'classicmodels'`**: the SQL script was missing the first
  time MySQL started. Check that `mysql-init/01-classicmodels.sql` exists,
  then `docker compose down -v && docker compose up -d`.
- **`spark-client` doesn't start**: it waits for MySQL to be `healthy`. Check
  `docker compose logs mysql` (large imports take a moment, SQL errors show here).
- **`Path does not exist: /opt/spark-data/empData.csv`**: check the file is in
  `data/` on the host, and that the worker has the `./data:/opt/spark-data`
  mount (`docker compose exec spark-worker ls /opt/spark-data`).
- **Executors die / job hangs with `Container killed`**: not enough memory;
  lower the memory in your job or raise the worker's `mem_limit`.
- **sbt: `unresolved dependency`**: check internet access; versions in
  `build.sbt` must be Scala 2.12 (`%%` picks `_2.12` automatically).
- **Worker not showing on the Master UI**: check
  `docker compose logs spark-worker` for connection errors.
- **`spark-submit` hangs with no executors**: confirm the worker is `ALIVE`
  on http://localhost:8080 and has enough free cores/memory.
- **Port already in use on the host**: change the left side of the port
  mapping in `docker-compose.yml` (e.g. `"18080:8080"`). MySQL is already on
  `3307` to avoid a local MySQL on `3306`.
- **Rebuilt Dockerfile but containers still use the old image**:
  `docker compose build` then `docker compose up -d --force-recreate`.
- **`docker compose build` fails with a DNS/lookup error**: your host's DNS
  resolver. Try `sudo systemctl restart systemd-resolved`, or add
  `{"dns": ["8.8.8.8", "1.1.1.1"]}` to `/etc/docker/daemon.json` and run
  `sudo systemctl restart docker`.

---

## 19. Quick Command Reference

```bash
# Build / start / stop
docker compose build
docker compose up -d
docker compose down            # keeps MySQL data
docker compose down -v         # wipes MySQL data + caches

# Enter the dev container
docker compose exec spark-client bash

# MySQL shell
docker compose exec mysql mysql -uroot -proot
docker compose exec mysql mysql -uroot -proot -e "SHOW DATABASES;"

# Interactive shells (inside spark-client)
pyspark      --master spark://spark-master:7077
spark-shell  --master spark://spark-master:7077

# PySpark job
spark-submit --master spark://spark-master:7077 /workspace/python/test_spark.py

# TP3: build + submit the sbt project
cd /workspace/scala/tp3 && sbt package
spark-submit --class <YourMainObject> --master spark://spark-master:7077 \
  target/scala-2.12/tp3-spark-mysql_2.12-0.1.0.jar

# JupyterLab
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root

# Verify tool versions (inside spark-client)
java -version && scala -version && sbt --version && python --version
spark-shell --version
```
