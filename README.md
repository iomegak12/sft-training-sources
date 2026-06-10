# Atlas — Snowflake Advanced (301–401) Training Labs

Hands-on lab assets for an advanced Snowflake course built around a fictional
market-data platform, **"Atlas"** (client scenario: *Fidelity Investments*). The
labs walk through clustering & micro-partition pruning, warehouse scaling,
dimensional modeling, bulk loading from S3, semi-structured JSON with `FLATTEN`,
Snowpipe auto-ingest, and Snowpipe Streaming via the Kafka connector.

The repository contains everything needed to **generate synthetic-but-realistic
data**, **stand up a local Kafka + Kafka Connect stack**, and **run the eight SQL
lab scripts** against a Snowflake account.

---

## What's inside

| Path | Purpose |
| --- | --- |
| [generate_market_data.py](generate_market_data.py) | Generates all batch/file lab data (ticks, trades, option chains, intraday drops) into `./data`. |
| [kafka_exec_producer.py](kafka_exec_producer.py) | Publishes synthetic order-execution events to a Kafka topic (Lab 7). |
| [docker-compose.yml](docker-compose.yml) | Local Kafka (KRaft) + Kafka Connect stack for the streaming lab. |
| [Dockerfile.connect](Dockerfile.connect) | Kafka Connect image with the Snowflake sink connector pre-installed. |
| [s3-notify.json](s3-notify.json) | S3 bucket notification config for Snowpipe auto-ingest (SQS event). |
| [queries/](queries/) | The eight ordered SQL lab scripts (`Query-1.sql` … `Query-8.sql`). |
| [pyproject.toml](pyproject.toml) | Python project metadata and dependencies (managed with `uv`). |

### The labs

| Lab | Script | Topic |
| --- | --- | --- |
| 1 | [queries/Query-1.sql](queries/Query-1.sql) | Database/schema/warehouse setup; load `TICKS`; clustering keys & pruning. |
| 2 | [queries/Query-2.sql](queries/Query-2.sql) | Warehouse sizing, multi-cluster scaling, result caching. |
| 3 | [queries/Query-3.sql](queries/Query-3.sql) | Dimensional model (`DIM_*` / `FACT_*`) in the `ANALYTICS` schema. |
| 4 | [queries/Query-4.sql](queries/Query-4.sql) | Storage integration + external stage; bulk `COPY` from S3. |
| 5 | [queries/Query-5.sql](queries/Query-5.sql) | Semi-structured option-chain JSON; `VARIANT` + `FLATTEN`. |
| 6 | [queries/Query-6.sql](queries/Query-6.sql) | Snowpipe auto-ingest from S3 (SQS notifications). |
| 7 | [queries/Query-7.sql](queries/Query-7.sql) | Snowpipe Streaming via the Kafka connector (key-pair auth). |
| 8 | [queries/Query-8.sql](queries/Query-8.sql) | Cross-fact analytics roll-up across quotes, trades, execs, options. |

---

## Prerequisites

- **Python** 3.12+ and [`uv`](https://docs.astral.sh/uv/) (or `pip`)
- **Docker** & Docker Compose (for Lab 7's Kafka stack)
- A **Snowflake** account with privileges to create databases, warehouses, and
  storage/streaming integrations
- An **AWS S3** bucket + IAM role for the S3-based labs (Labs 4 & 6)

---

## Quick start

### 1. Generate the lab data

```bash
uv sync                       # install dependencies
uv run python generate_market_data.py          # full dataset
uv run python generate_market_data.py --quick  # smaller, fast smoke test
```

Files are written under `./data`. The generator is seeded
(`SEED = 20240115`), so every run — and every student — gets identical data.

### 2. Run the SQL labs

Open `queries/Query-1.sql` … `Query-8.sql` in a Snowflake worksheet (or `snowsql`)
**in order**. Replace placeholder identifiers (IAM role ARN, S3 bucket, RSA public
key) with values for your own account before running Labs 4, 6, and 7.

### 3. Streaming lab (Lab 7)

```bash
docker compose up -d                            # start Kafka + Connect
uv run python kafka_exec_producer.py \
    --bootstrap localhost:29092 \
    --topic atlas.executions \
    --rate 20 --count 2000
```

Then register the Snowflake sink connector against Kafka Connect (`http://localhost:8083`)
so events land in `FIDELITY_ATLAS.RAW.RAW_EXECUTIONS`.

---

## Notes

- All data is **synthetic**. Symbols, prices, and Greeks are randomly generated
  and do not represent real market data.
- The labs intentionally start with **poorly clustered** data so students can
  measure pruning improvements after adding a clustering key.
- Replace every placeholder credential/ARN/key with your own — the sample values
  in the SQL scripts are illustrative only.

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues,
[CONTRIBUTING.md](CONTRIBUTING.md) to propose changes, and
[CHANGELOG.md](CHANGELOG.md) for release history.

## License

Released under the [MIT License](LICENSE).
