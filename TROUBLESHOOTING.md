# Troubleshooting

Common issues encountered while running the Atlas Snowflake labs, grouped by
area. If you hit something not covered here, please
[open an issue](CONTRIBUTING.md).

---

## Data generation

### `ModuleNotFoundError: No module named 'numpy'` (or `pandas`)
The generator depends on `numpy` and `pandas`. Install dependencies first:

```bash
uv sync
# or
pip install numpy pandas
```

> Note: `pyproject.toml` currently pins only `kafka-python` (needed for Lab 7).
> `numpy`/`pandas` are required by `generate_market_data.py` — add them with
> `uv add numpy pandas` if they aren't already in your environment.

### The `data/` folder is empty after running
`generate_market_data.py` writes into `./data` relative to the script location.
Confirm you ran it from the repo root and check the printed summary table at the
end of the run. Use `--quick` to verify the pipeline works with smaller volumes.

### Every run produces identical files
That's intentional. The generator uses a fixed seed (`SEED = 20240115`) so all
students get the same data. Change the seed if you need different values.

---

## Snowflake SQL labs

### `Object does not exist` for `TICKS_CLUSTERED`, `FACT_*`, etc.
The scripts are **ordered and cumulative**. Run `Query-1.sql` through
`Query-8.sql` in sequence — later labs depend on tables, stages, and warehouses
created in earlier ones.

### `Insufficient privileges to operate on ...`
Storage integrations, streaming users, and `GRANT` statements (Labs 4, 6, 7)
require an elevated role such as `ACCOUNTADMIN` (or a custom role with the
relevant `CREATE INTEGRATION` / `CREATE USER` privileges). Run:

```sql
USE ROLE ACCOUNTADMIN;
```

### Query timing/credits look the same across runs
Result caching is masking real compute. The labs disable it explicitly:

```sql
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
```

Make sure this ran in your current session before measuring.

---

## S3 / storage integration (Labs 4 & 6)

### `COPY` finds no files / `LIST @STAGE` returns nothing
- Confirm files were uploaded to the exact prefix in the stage `URL`
  (`batch/` for Lab 4, `autoingest/` for Lab 6).
- Re-run `DESC INTEGRATION ATLAS_S3_INT` and verify the
  `STORAGE_AWS_IAM_USER_ARN` and `STORAGE_AWS_EXTERNAL_ID` are reflected in your
  IAM role's trust policy.

### `Access Denied` during `COPY` or `LIST`
The IAM role ARN in the integration must match a role that trusts Snowflake's
generated IAM user/external ID, and grants `s3:GetObject` / `s3:ListBucket` on
the bucket and prefix. Replace the placeholder ARN
(`arn:aws:iam::...:role/FidelityAtlasSnowflakeRole`) with your own.

### Snowpipe auto-ingest doesn't fire (Lab 6)
- The S3 bucket needs an event notification pointed at the pipe's SQS ARN.
  See [s3-notify.json](s3-notify.json) and replace the `QueueArn` with the ARN
  from `SHOW PIPES` / `DESC PIPE ATLAS_TICKS_PIPE` (`notification_channel`).
- Notifications only trigger on **new** object creation. Files already in the
  prefix before the notification was configured must be loaded manually
  (`ALTER PIPE ... REFRESH`).

---

## Kafka streaming (Lab 7)

### Producer: `NoBrokersAvailable`
Use the **external** listener port from outside Docker:

```bash
uv run python kafka_exec_producer.py --bootstrap localhost:29092 ...
```

Port `9092` is the in-cluster listener; `29092` is exposed to the host
(see [docker-compose.yml](docker-compose.yml)).

### Producer: `Install dependency first: pip install kafka-python`
Install the Kafka client: `uv add kafka-python` (or `pip install kafka-python`).

### Kafka Connect won't start / connector missing
- Give the `connect` container time to build — it installs the Snowflake
  connector at image-build time via `confluent-hub` (see
  [Dockerfile.connect](Dockerfile.connect)).
- Check health: `curl http://localhost:8083/connector-plugins` and look for
  `com.snowflake.kafka.connector.SnowflakeSinkConnector`.

### Snowflake sink: authentication / `private key` errors
Lab 7 uses **key-pair auth** for `streaming_user`. Ensure:
- The **public** key set via `ALTER USER streaming_user SET RSA_PUBLIC_KEY=...`
  matches the **private** key configured in the connector.
- The private key is supplied unencrypted (or with the passphrase) in the
  connector config — never commit it (see [.gitignore](.gitignore)).

### Rows not landing in `RAW_EXECUTIONS`
- Confirm the connector's `topics` matches your producer `--topic`
  (`atlas.executions`).
- Verify grants from `Query-7.sql` ran:
  `GRANT INSERT, SELECT ON TABLE RAW_EXECUTIONS TO USER streaming_user;`
- Inspect connector status: `curl http://localhost:8083/connectors/<name>/status`.

---

## Docker

### Port already in use (`29092`, `8083`)
Another process (or a previous stack) holds the port. Stop it or change the host
port mapping in [docker-compose.yml](docker-compose.yml), then
`docker compose down && docker compose up -d`.

### Stale state between runs
```bash
docker compose down -v   # removes volumes/topics for a clean slate
docker compose up -d
```
