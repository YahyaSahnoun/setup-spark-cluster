# Spark Docker Environment

A self-contained Docker Compose lab for practicing Apache Spark with **both
PySpark and Scala**, against a real (if tiny) Spark Standalone cluster
running on your own machine.

---

## 1. Overview

This project gives you three containers:

| Service        | Role                                                        |
|----------------|--------------------------------------------------------------|
| `spark-master` | Spark Standalone Master                                      |
| `spark-worker` | One Spark Worker, registered with the master                 |
| `spark-client` | Dev container: `pyspark`, `spark-shell`, `spark-submit`, `scalac` |

You do all your work from `spark-client`. `spark-master` and `spark-worker`
just need to be up and running in the background.

---

## 2. Architecture

```text
                         Host
                          │
                    Docker Compose
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
  spark-master       spark-worker      spark-client
   (UI :8080)          (UI :8081)       (UI :4040)
        │                 │                 │
        │                 │          ┌──────┴──────┐
        │                 │          │             │
        │                 │       PySpark        Scala
        │                 │          │             │
        └─────────────────┴──────────┴─────────────┘
                  spark://spark-master:7077
```

All three containers share **one Docker image** (built once from the single
`Dockerfile` in this repo), so Java, Scala, Spark and PySpark are guaranteed
to be identical everywhere. `spark-master` and `spark-worker` just run
different Spark daemon processes from that same image.

---

## 3. Requirements

- Pop!_OS 24.04 (or any recent Linux/macOS/Windows with Docker)
- Docker Engine + Docker Compose v2 (`docker compose`, not the old
  `docker-compose`)
- ~4 GB of free RAM for the containers (comfortable on a 16 GB machine)
- Internet access the first time you build (to download Spark/Scala)

---

## 4. Project Structure

```text
spark-docker/
│
├── docker-compose.yml
├── Dockerfile
├── README.md
│
├── python/
│   └── test_spark.py
│
├── scala/
│   └── TestSpark.scala
│
└── data/
    └── .gitkeep        # keeps the empty folder in version control
```

`data/` is mounted into every container at `/opt/spark-data` — drop CSVs,
Parquet files, etc. there and all three services can see them.

The only file added beyond your spec is `data/.gitkeep`, purely so the empty
`data/` folder survives a `git add`/`git commit` (Git does not track empty
directories). It has no effect on Docker or Spark.

---

## 5. Version Compatibility

| Component | Version         | Why it's compatible                                   |
|-----------|-----------------|--------------------------------------------------------|
| Java      | 17 (Temurin)    | Spark 3.3+ officially supports Java 17                |
| Spark     | 3.5.3           | Latest stable 3.5.x release                           |
| Scala     | 2.12.18         | Spark 3.5.x is built against Scala 2.12                |
| Python    | 3.10 (Ubuntu 22.04 base) | Within PySpark 3.5.x's supported range (3.8–3.12) |
| PySpark   | 3.5.3 (pip)     | Pinned to match the Spark cluster version exactly     |

Keeping PySpark's pip version identical to the cluster's Spark version is the
single most important compatibility rule here — a mismatch is the #1 cause
of cryptic `spark-submit` errors.

---

## 6. Setup

```bash
# from inside the spark-docker/ directory
docker compose build
```

This builds the shared image (`spark-lab:3.5.3`) once. The first build takes
a few minutes (downloading Spark + Scala); later builds are cached.

---

## 7. Start the Environment

```bash
docker compose up -d
```

Check everything is running:

```bash
docker compose ps
```

You should see `spark-master`, `spark-worker` and `spark-client` all `Up`.

---

## 8. Check the Spark Cluster

Tail the worker's logs and look for a registration message:

```bash
docker compose logs spark-worker | grep -i "registered"
```

You should see a line like:

```text
INFO Worker: Successfully registered with master spark://spark-master:7077
```

You can also confirm it visually — see the next section.

---

## 9. Access the Spark Web UI

With the ports as configured in `docker-compose.yml`:

| UI                  | URL                            | What it shows                                   |
|---------------------|---------------------------------|--------------------------------------------------|
| Spark Master UI     | http://localhost:8080           | Registered workers, running/completed applications |
| Spark Worker UI     | http://localhost:8081           | That worker's cores, memory, running executors    |
| Spark Application UI| http://localhost:4040            | Jobs/stages/tasks for whatever app is *currently* running from `spark-client` |

Open http://localhost:8080 first — under "Workers" you should see one worker
listed as `ALIVE`. That's your confirmation the cluster is healthy.

The Application UI at port 4040 only exists **while a job is actively
running** (opened by the driver). Once the job finishes, it disappears.

---

## 10. Test PySpark

### 10.1 Interactive PySpark

Enter the client container:

```bash
docker compose exec spark-client bash
```

Then launch the interactive shell, pointed at the real cluster:

```bash
pyspark --master spark://spark-master:7077
```

What happens: `pyspark` starts a Python REPL with a `SparkSession` already
created for you as `spark`. Because you passed `--master`, the **driver**
runs inside `spark-client`, but the actual Spark **executors** are launched
by `spark-worker` and do the real computation. You'll see the application
appear on the Master UI (http://localhost:8080) and get a live UI at
http://localhost:4040 while the shell is open.

Try it:

```python
>>> spark.range(1000).count()
```

Type `exit()` or press `Ctrl-D` to leave.

### 10.2 Run the PySpark Test

Run it locally first (no cluster, quick sanity check):

```bash
python3 python/test_spark.py
```

Then submit it to the real cluster:

```bash
spark-submit \
  --master spark://spark-master:7077 \
  /workspace/python/test_spark.py
```

- `spark-submit` is Spark's standard tool for launching an application
  (Python, Scala or Java) against a cluster.
- `--master spark://spark-master:7077` tells Spark which cluster manager
  and master to use — here, our own Standalone master.
- The **driver** (the process running your `main`/script logic and
  coordinating the job) runs on `spark-client`, the machine you invoked
  `spark-submit` from.
- The **executors** (the processes that actually run tasks on data
  partitions) are launched by `spark-worker`, using the cores/memory you
  gave it (`--cores 2 --memory 2g` in `docker-compose.yml`).

### 10.3 Understanding the PySpark Test

`python/test_spark.py`:

1. Creates a `SparkSession`.
2. Prints `spark.version`.
3. Builds a 5-row DataFrame of `(name, age, city)`.
4. Shows it with `.show()`.
5. Applies `.filter(age > 25)`, then `.select(...)`, then `.groupBy("city").count()` — all lazy transformations.
6. Calls `.count()` — an **action** — which is what actually triggers a Spark job (you'll see it appear on the Master/Application UI at that moment).
7. Stops the `SparkSession` with `.stop()`.

---

## 11. Test Scala Spark

### 11.1 Interactive Scala Shell

Inside `spark-client`:

```bash
spark-shell --master spark://spark-master:7077
```

Just like `pyspark`, this drops you into a Scala REPL with `spark:
SparkSession` already created, connected to the real cluster. Try:

```scala
spark.range(1000).count()
```

Exit with `:quit`.

### 11.2 Compile the Scala Application

Unlike a `.py` file, a `.scala` file cannot be handed to `spark-submit`
directly — it must be compiled into `.class` files and packaged into a JAR
first:

```text
Scala source (TestSpark.scala)
    ↓  scalac
.class files
    ↓  jar
TestSpark.jar
    ↓  spark-submit
Spark cluster
```

Inside `spark-client`:

```bash
cd /workspace/scala
mkdir -p build/classes

# Compile against the Spark jars already installed in the image
scalac -classpath "$SPARK_HOME/jars/*" -d build/classes TestSpark.scala

# Package the compiled classes into a JAR
cd build/classes
jar cf ../TestSpark.jar .
cd ../..
```

You now have `/workspace/scala/build/TestSpark.jar`.

### 11.3 Submit the Scala Application

```bash
spark-submit \
  --class TestSpark \
  --master spark://spark-master:7077 \
  /workspace/scala/build/TestSpark.jar
```

- `--class TestSpark` tells Spark which JVM class contains the entry point
  (our file declares `object TestSpark extends App`, so the class name is
  simply `TestSpark`, with no package prefix).
- Driver/executor split is identical to the PySpark case: the driver runs on
  `spark-client`, executors run on `spark-worker`.

### Understanding the Scala Test

`scala/TestSpark.scala` mirrors the PySpark test step for step: create
`SparkSession` → print version → build a DataFrame → `show()` → `filter` →
`select` → `groupBy().count()` (transformations) → `.count()` (the action
that triggers execution) → `spark.stop()`.

---

## 12. The `data/` Directory

Mounted into all three containers at `/opt/spark-data`. Use it for any file
your scripts need to read or write, e.g.:

```python
df = spark.read.csv("/opt/spark-data/mydata.csv", header=True)
```

Files placed here from the host (`spark-docker/data/`) are visible to
`spark-master`, `spark-worker` and `spark-client` alike.

---

## 13. Adding Your Own Projects

- **PySpark**: drop new `.py` files into `python/` — they're live inside
  `spark-client` at `/workspace/python/` immediately, no rebuild needed.
- **Scala**: drop new `.scala` files into `scala/`, compile them the same
  way as `TestSpark.scala` (section 11.2), then `spark-submit` the resulting
  JAR.
- Because the whole project directory is bind-mounted into `spark-client`
  (`.:/workspace`), you only need to rebuild the image
  (`docker compose build`) if you change the `Dockerfile` itself (e.g. to
  add a new Python or Java library).

---

## 14. Stopping the Environment

```bash
docker compose down
```

Add `-v` if you ever add named volumes and want to wipe them too (this
setup uses only bind mounts, so `-v` isn't required here).

---

## 15. Troubleshooting

- **Worker not showing on the Master UI**: check
  `docker compose logs spark-worker` for connection errors, and make sure
  `spark-master` was up before the worker tried to register
  (`depends_on` handles ordering, but not full readiness).
- **`spark-submit` hangs with no executors**: confirm the worker is `ALIVE`
  on http://localhost:8080 and that its free cores/memory are enough for
  your job's requested resources.
- **Port already in use on the host**: another process is using 8080/8081/7077/4040 —
  either stop it or change the left-hand side of the port mappings in
  `docker-compose.yml` (e.g. `"18080:8080"`).
- **Rebuilt Dockerfile but containers still use the old image**: run
  `docker compose build` then `docker compose up -d --force-recreate`.

---

## 16. Quick Command Reference

```bash
# Build the shared image
docker compose build

# Start the cluster
docker compose up -d

# Enter the dev container
docker compose exec spark-client bash

# Interactive shells (inside spark-client)
pyspark      --master spark://spark-master:7077
spark-shell  --master spark://spark-master:7077

# Submit PySpark job
spark-submit --master spark://spark-master:7077 /workspace/python/test_spark.py

# Compile + submit Scala job
cd /workspace/scala && mkdir -p build/classes
scalac -classpath "$SPARK_HOME/jars/*" -d build/classes TestSpark.scala
cd build/classes && jar cf ../TestSpark.jar . && cd ../..
spark-submit --class TestSpark --master spark://spark-master:7077 /workspace/scala/build/TestSpark.jar

# Verify tool versions (inside spark-client)
java -version
scala -version
python --version
spark-shell --version
pyspark --version

# Stop everything
docker compose down
```
