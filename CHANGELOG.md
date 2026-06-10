# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Project documentation: `README.md`, `CONTRIBUTING.md`, `TROUBLESHOOTING.md`,
  `CHANGELOG.md`, `LICENSE` (MIT), and `.gitignore`.

## [0.1.0] - 2026-06-10

### Added
- Synthetic market-data generator (`generate_market_data.py`) producing data for
  Labs 1, 4, 5, and 6: historical ticks, nightly trade batches, nested
  option-chain JSON, and intraday Snowpipe drop files. Deterministic via a fixed
  seed.
- Kafka execution-event producer (`kafka_exec_producer.py`) for Lab 7
  (Snowpipe Streaming).
- Local streaming stack: `docker-compose.yml` (Kafka in KRaft mode + Kafka
  Connect) and `Dockerfile.connect` (Snowflake sink connector pre-installed).
- S3 event-notification config (`s3-notify.json`) for Snowpipe auto-ingest.
- Eight ordered SQL lab scripts (`queries/Query-1.sql` … `Query-8.sql`) covering
  setup & clustering/pruning, warehouse scaling, dimensional modeling, S3 bulk
  load, semi-structured JSON + `FLATTEN`, Snowpipe auto-ingest, Snowpipe
  Streaming, and a cross-fact analytics roll-up.
- Python project metadata (`pyproject.toml`, `uv.lock`).

[Unreleased]: https://example.com/compare/v0.1.0...HEAD
[0.1.0]: https://example.com/releases/tag/v0.1.0
