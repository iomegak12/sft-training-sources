-- ============================================================================
-- Day2_Reset_Catchup.sql
-- FUIDP · Snowflake Training · Run at the START of Day 2 (Lab 0)
--
-- PURPOSE: Verify + rebuild the Day 1 end state, idempotently.
--   - Safe to run multiple times (CREATE IF NOT EXISTS / conditional seeding).
--   - NO dependency on S3, Snowpipe, or Kafka: all data is regenerated
--     in-database, so even attendees whose Day 1 AWS labs failed start
--     Day 2 with a complete, identical state.
--   - Also your mid-day recovery tool: if someone wrecks a table during
--     Day 2, re-run the relevant section.
--
-- WHAT IT GUARANTEES AFTERWARD:
--   Warehouses : WH_INGEST (XS), WH_ANALYTICS (S, multi-cluster 1-3)
--   Database   : FUIDP with RAW / STAGING / ANALYTICS schemas
--   RAW        : securities_master(36) · accounts(200) · trades(8,000)
--                trades_stream(1,500)  · market_ticks_json(3,000)
--                trades_large(5,000,000)  <-- mandatory for Labs 13-14
--   STAGING    : market_ticks (typed from JSON)
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ----------------------------------------------------------------------------
-- 1. Warehouses
-- ----------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS WH_INGEST
  WAREHOUSE_SIZE='XSMALL' AUTO_SUSPEND=60 AUTO_RESUME=TRUE INITIALLY_SUSPENDED=TRUE
  COMMENT='FUIDP ingestion workload';

CREATE WAREHOUSE IF NOT EXISTS WH_ANALYTICS
  WAREHOUSE_SIZE='SMALL' AUTO_SUSPEND=60 AUTO_RESUME=TRUE INITIALLY_SUSPENDED=TRUE
  MIN_CLUSTER_COUNT=1 MAX_CLUSTER_COUNT=3 SCALING_POLICY='STANDARD'
  COMMENT='FUIDP analytics workload';

USE WAREHOUSE WH_ANALYTICS;

-- ----------------------------------------------------------------------------
-- 2. Database + schemas
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS FUIDP;
USE DATABASE FUIDP;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS STAGING;
CREATE SCHEMA IF NOT EXISTS ANALYTICS;
USE SCHEMA FUIDP.RAW;

-- ----------------------------------------------------------------------------
-- 3. RAW tables (created empty if missing)
-- ----------------------------------------------------------------------------
CREATE TRANSIENT TABLE IF NOT EXISTS securities_master (
  symbol STRING, company_name STRING, asset_class STRING,
  sector STRING, currency STRING, exchange STRING);

CREATE TRANSIENT TABLE IF NOT EXISTS accounts (
  account_id STRING, customer_id STRING, customer_name STRING,
  ssn STRING, email STRING, segment STRING, advisor_id STRING,
  country STRING, open_date DATE);

CREATE TRANSIENT TABLE IF NOT EXISTS trades (
  trade_id STRING, account_id STRING, symbol STRING, side STRING,
  quantity NUMBER, price NUMBER(18,4), trade_ts TIMESTAMP_NTZ,
  settlement_date DATE, venue STRING);

CREATE TRANSIENT TABLE IF NOT EXISTS trades_stream (
  trade_id STRING, account_id STRING, symbol STRING, side STRING,
  quantity NUMBER, price NUMBER(18,4), trade_ts TIMESTAMP_NTZ,
  settlement_date DATE, venue STRING);

CREATE TRANSIENT TABLE IF NOT EXISTS market_ticks_json (
  raw VARIANT, load_ts TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP());

-- ----------------------------------------------------------------------------
-- 4. Seed securities_master (only if empty)
-- ----------------------------------------------------------------------------
INSERT INTO securities_master
SELECT * FROM (
  SELECT column1 AS symbol, column2 AS company_name, column3 AS asset_class,
         column4 AS sector, column5 AS currency, column6 AS exchange
  FROM VALUES
  ('AAPL','Apple Inc.','EQUITY','Technology','USD','NASDAQ'),
  ('MSFT','Microsoft Corp.','EQUITY','Technology','USD','NASDAQ'),
  ('NVDA','NVIDIA Corp.','EQUITY','Technology','USD','NASDAQ'),
  ('GOOGL','Alphabet Inc.','EQUITY','Technology','USD','NASDAQ'),
  ('AMZN','Amazon.com Inc.','EQUITY','Consumer Discretionary','USD','NASDAQ'),
  ('TSLA','Tesla Inc.','EQUITY','Consumer Discretionary','USD','NASDAQ'),
  ('META','Meta Platforms Inc.','EQUITY','Communication Services','USD','NASDAQ'),
  ('NFLX','Netflix Inc.','EQUITY','Communication Services','USD','NASDAQ'),
  ('JPM','JPMorgan Chase & Co.','EQUITY','Financials','USD','NYSE'),
  ('BAC','Bank of America Corp.','EQUITY','Financials','USD','NYSE'),
  ('GS','Goldman Sachs Group','EQUITY','Financials','USD','NYSE'),
  ('V','Visa Inc.','EQUITY','Financials','USD','NYSE'),
  ('JNJ','Johnson & Johnson','EQUITY','Health Care','USD','NYSE'),
  ('PFE','Pfizer Inc.','EQUITY','Health Care','USD','NYSE'),
  ('UNH','UnitedHealth Group','EQUITY','Health Care','USD','NYSE'),
  ('XOM','Exxon Mobil Corp.','EQUITY','Energy','USD','NYSE'),
  ('CVX','Chevron Corp.','EQUITY','Energy','USD','NYSE'),
  ('KO','Coca-Cola Co.','EQUITY','Consumer Staples','USD','NYSE'),
  ('PEP','PepsiCo Inc.','EQUITY','Consumer Staples','USD','NASDAQ'),
  ('WMT','Walmart Inc.','EQUITY','Consumer Staples','USD','NYSE'),
  ('DIS','Walt Disney Co.','EQUITY','Communication Services','USD','NYSE'),
  ('BA','Boeing Co.','EQUITY','Industrials','USD','NYSE'),
  ('CAT','Caterpillar Inc.','EQUITY','Industrials','USD','NYSE'),
  ('GE','General Electric','EQUITY','Industrials','USD','NYSE'),
  ('INTC','Intel Corp.','EQUITY','Technology','USD','NASDAQ'),
  ('AMD','Advanced Micro Devices','EQUITY','Technology','USD','NASDAQ'),
  ('ORCL','Oracle Corp.','EQUITY','Technology','USD','NYSE'),
  ('CRM','Salesforce Inc.','EQUITY','Technology','USD','NYSE'),
  ('T','AT&T Inc.','EQUITY','Communication Services','USD','NYSE'),
  ('VZ','Verizon Communications','EQUITY','Communication Services','USD','NYSE'),
  ('FXAIX','Fidelity 500 Index Fund','MUTUAL_FUND','Mutual Fund','USD','NASDAQ'),
  ('FCNTX','Fidelity Contrafund','MUTUAL_FUND','Mutual Fund','USD','NASDAQ'),
  ('FZROX','Fidelity ZERO Total Market','MUTUAL_FUND','Mutual Fund','USD','NASDAQ'),
  ('SPY','SPDR S&P 500 ETF','ETF','ETF','USD','NYSE Arca'),
  ('QQQ','Invesco QQQ Trust','ETF','ETF','USD','NYSE Arca'),
  ('VTI','Vanguard Total Stock Market ETF','ETF','ETF','USD','NYSE Arca')
)
WHERE (SELECT COUNT(*) FROM securities_master) = 0;

-- ----------------------------------------------------------------------------
-- 5. Seed accounts: 200 rows (only if empty). Synthetic PII for Day 3 masking.
-- ----------------------------------------------------------------------------
INSERT INTO accounts
SELECT
  'ACC'||LPAD(SEQ4()+1,5,'0'),
  'CUST'||LPAD(SEQ4()+1,5,'0'),
  ARRAY_CONSTRUCT('James','Mary','John','Patricia','Robert','Jennifer','Priya','Wei',
                  'Carlos','Aisha')[UNIFORM(0,9,RANDOM())]::string || ' ' ||
  ARRAY_CONSTRUCT('Smith','Johnson','Williams','Garcia','Patel','Chen','Kim','Nguyen',
                  'Singh','Lopez')[UNIFORM(0,9,RANDOM())]::string,
  UNIFORM(100,899,RANDOM())||'-'||UNIFORM(10,99,RANDOM())||'-'||UNIFORM(1000,9999,RANDOM()),
  'client'||(SEQ4()+1)||'@example.com',
  ARRAY_CONSTRUCT('RETAIL','WEALTH','INSTITUTIONAL','RETIREMENT_401K')[UNIFORM(0,3,RANDOM())]::string,
  'ADV'||LPAD(UNIFORM(1,20,RANDOM()),3,'0'),
  'US',
  DATEADD('day', UNIFORM(0,2700,RANDOM()), '2018-01-01'::date)
FROM TABLE(GENERATOR(ROWCOUNT => 200))
WHERE (SELECT COUNT(*) FROM accounts) = 0;

-- ----------------------------------------------------------------------------
-- 6. Helper view for synthetic trade generation (8 active symbols)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TEMPORARY TABLE _symbols AS
SELECT column1 AS symbol, column2 AS base_price FROM VALUES
 ('AAPL',195),('MSFT',410),('NVDA',880),('JPM',190),
 ('SPY',520),('FXAIX',175),('TSLA',180),('AMZN',185);

-- ----------------------------------------------------------------------------
-- 7. Seed trades: 8,000 rows for 2024-06-03 (only if empty)
-- ----------------------------------------------------------------------------
INSERT INTO trades
SELECT
  'TRD'||LPAD(SEQ8()+1,8,'0'),
  'ACC'||LPAD(UNIFORM(1,200,RANDOM()),5,'0'),
  s.symbol,
  IFF(UNIFORM(0,1,RANDOM())=0,'BUY','SELL'),
  UNIFORM(1,1000,RANDOM()),
  ROUND(s.base_price * UNIFORM(95,105,RANDOM())/100, 2),
  DATEADD('second', UNIFORM(0, 6*3600, RANDOM()), '2024-06-03 09:30:00'::timestamp_ntz),
  '2024-06-05'::date,
  ARRAY_CONSTRUCT('NYSE','NASDAQ','ARCA','BATS','IEX')[UNIFORM(0,4,RANDOM())]::string
FROM TABLE(GENERATOR(ROWCOUNT => 8000)) g
JOIN _symbols s ON s.symbol = ARRAY_CONSTRUCT('AAPL','MSFT','NVDA','JPM','SPY','FXAIX','TSLA','AMZN')
                              [UNIFORM(0,7,RANDOM())]::string
WHERE (SELECT COUNT(*) FROM trades) = 0;

-- ----------------------------------------------------------------------------
-- 8. Seed trades_stream: 1,500 rows for 2024-06-04 (only if empty)
--    (Stands in for the Snowpipe-ingested incremental batch.)
-- ----------------------------------------------------------------------------
INSERT INTO trades_stream
SELECT
  'TRD'||LPAD(SEQ8()+8001,8,'0'),
  'ACC'||LPAD(UNIFORM(1,200,RANDOM()),5,'0'),
  s.symbol,
  IFF(UNIFORM(0,1,RANDOM())=0,'BUY','SELL'),
  UNIFORM(1,1000,RANDOM()),
  ROUND(s.base_price * UNIFORM(95,105,RANDOM())/100, 2),
  DATEADD('second', UNIFORM(0, 6*3600, RANDOM()), '2024-06-04 09:30:00'::timestamp_ntz),
  '2024-06-06'::date,
  ARRAY_CONSTRUCT('NYSE','NASDAQ','ARCA','BATS','IEX')[UNIFORM(0,4,RANDOM())]::string
FROM TABLE(GENERATOR(ROWCOUNT => 1500)) g
JOIN _symbols s ON s.symbol = ARRAY_CONSTRUCT('AAPL','MSFT','NVDA','JPM','SPY','FXAIX','TSLA','AMZN')
                              [UNIFORM(0,7,RANDOM())]::string
WHERE (SELECT COUNT(*) FROM trades_stream) = 0;

-- ----------------------------------------------------------------------------
-- 9. Seed market_ticks_json: 3,000 NDJSON-style VARIANT rows (only if empty)
-- ----------------------------------------------------------------------------
INSERT INTO market_ticks_json (raw)
SELECT OBJECT_CONSTRUCT(
  'symbol',   s.symbol,
  'price',    ROUND(s.base_price * UNIFORM(97,103,RANDOM())/100, 2),
  'bid',      ROUND(s.base_price * UNIFORM(96,102,RANDOM())/100, 4),
  'ask',      ROUND(s.base_price * UNIFORM(98,104,RANDOM())/100, 4),
  'volume',   UNIFORM(100,50000,RANDOM()),
  'exchange', ARRAY_CONSTRUCT('NYSE','NASDAQ','ARCA')[UNIFORM(0,2,RANDOM())]::string,
  'event_ts', TO_VARCHAR(DATEADD('millisecond', SEQ4()*800, '2024-06-04 09:30:00'::timestamp_ntz),
                         'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'))
FROM TABLE(GENERATOR(ROWCOUNT => 3000)) g
JOIN _symbols s ON s.symbol = ARRAY_CONSTRUCT('AAPL','MSFT','NVDA','JPM','SPY','FXAIX','TSLA','AMZN')
                              [UNIFORM(0,7,RANDOM())]::string
WHERE (SELECT COUNT(*) FROM market_ticks_json) = 0;

-- ----------------------------------------------------------------------------
-- 10. STAGING.market_ticks (typed) — rebuild unconditionally (cheap)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE FUIDP.STAGING.market_ticks AS
SELECT raw:symbol::string AS symbol, raw:price::number(18,4) AS price,
       raw:bid::number(18,4) AS bid, raw:ask::number(18,4) AS ask,
       raw:volume::int AS volume, raw:exchange::string AS exchange,
       raw:event_ts::timestamp_ntz AS event_ts
FROM FUIDP.RAW.market_ticks_json;

-- ----------------------------------------------------------------------------
-- 11. trades_large: 5,000,000 rows — MANDATORY for Labs 13-14 (only if absent
--     or wrong size). ~30-60s on SMALL; the script bumps to LARGE temporarily.
-- ----------------------------------------------------------------------------
ALTER WAREHOUSE WH_ANALYTICS SET WAREHOUSE_SIZE='LARGE';

CREATE TRANSIENT TABLE IF NOT EXISTS trades_large (
  trade_id STRING, account_id STRING, symbol STRING, side STRING,
  quantity NUMBER, price NUMBER(18,4), trade_ts TIMESTAMP_NTZ);

INSERT INTO trades_large
SELECT
  'TRD'||LPAD(SEQ8(),10,'0'),
  'ACC'||LPAD(UNIFORM(1,200,RANDOM()),5,'0'),
  ARRAY_CONSTRUCT('AAPL','MSFT','NVDA','JPM','SPY','FXAIX','TSLA','AMZN')
    [UNIFORM(0,7,RANDOM())]::string,
  IFF(UNIFORM(0,1,RANDOM())=0,'BUY','SELL'),
  UNIFORM(1,1000,RANDOM()),
  ROUND(UNIFORM(35,480,RANDOM()) + RANDOM()/1e9, 2),
  DATEADD('second', UNIFORM(0, 60*60*24*30, RANDOM()), '2024-06-01'::timestamp_ntz)
FROM TABLE(GENERATOR(ROWCOUNT => 5000000))
WHERE (SELECT COUNT(*) FROM trades_large) < 5000000;

ALTER WAREHOUSE WH_ANALYTICS SET WAREHOUSE_SIZE='SMALL';

-- ----------------------------------------------------------------------------
-- 12. VERIFICATION — run this block; every row should say PASS
-- ----------------------------------------------------------------------------
SELECT 'securities_master' AS object, COUNT(*) AS rows_found, 36 AS expected,
       IFF(COUNT(*)>=36,'PASS','FAIL') AS status FROM securities_master
UNION ALL SELECT 'accounts', COUNT(*), 200, IFF(COUNT(*)>=200,'PASS','FAIL') FROM accounts
UNION ALL SELECT 'trades', COUNT(*), 8000, IFF(COUNT(*)>=8000,'PASS','FAIL') FROM trades
UNION ALL SELECT 'trades_stream', COUNT(*), 1500, IFF(COUNT(*)>=1500,'PASS','FAIL') FROM trades_stream
UNION ALL SELECT 'market_ticks_json', COUNT(*), 3000, IFF(COUNT(*)>=3000,'PASS','FAIL') FROM market_ticks_json
UNION ALL SELECT 'staging.market_ticks', COUNT(*), 3000, IFF(COUNT(*)>=3000,'PASS','FAIL') FROM FUIDP.STAGING.market_ticks
UNION ALL SELECT 'trades_large', COUNT(*), 5000000, IFF(COUNT(*)>=5000000,'PASS','FAIL') FROM trades_large;

-- ============================================================================
-- END. All PASS => you are at the canonical Day 1 end state. Proceed to Lab 8.
-- ============================================================================
