USE SCHEMA FUIDP.ANALYTICS;

-- Target: current positions per account+symbol
CREATE OR REPLACE TABLE positions (
  account_id STRING, symbol STRING, net_quantity NUMBER,
  last_trade_ts TIMESTAMP_NTZ, updated_at TIMESTAMP_NTZ);

-- Fresh stream for the pipeline:
CREATE OR REPLACE STREAM FUIDP.RAW.strm_trades_pipeline ON TABLE FUIDP.RAW.trades_stream;

-- Root task: every minute (training cadence), ONLY if the stream has data
CREATE OR REPLACE TASK FUIDP.RAW.task_update_positions
  WAREHOUSE = WH_INGEST
  SCHEDULE  = '1 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('FUIDP.RAW.strm_trades_pipeline')
AS
  MERGE INTO FUIDP.ANALYTICS.positions p
  USING (
    SELECT account_id, symbol,
           SUM(IFF(side='BUY', quantity, -quantity)) AS delta_qty,
           MAX(trade_ts) AS max_ts
    FROM FUIDP.RAW.strm_trades_pipeline
    GROUP BY account_id, symbol
  ) s
  ON p.account_id = s.account_id AND p.symbol = s.symbol
  WHEN MATCHED THEN UPDATE SET
    net_quantity = p.net_quantity + s.delta_qty,
    last_trade_ts = GREATEST(p.last_trade_ts, s.max_ts),
    updated_at = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT
    (account_id, symbol, net_quantity, last_trade_ts, updated_at)
    VALUES (s.account_id, s.symbol, s.delta_qty, s.max_ts, CURRENT_TIMESTAMP());

-- Child task: refresh a valuation summary AFTER positions update
CREATE OR REPLACE TASK FUIDP.RAW.task_refresh_valuation
  WAREHOUSE = WH_INGEST
  AFTER FUIDP.RAW.task_update_positions
AS
  CREATE OR REPLACE TABLE FUIDP.ANALYTICS.portfolio_valuation AS
  SELECT p.account_id, SUM(p.net_quantity * m.price) AS market_value
  FROM FUIDP.ANALYTICS.positions p
  JOIN (SELECT symbol, MAX_BY(price, event_ts) AS price
        FROM FUIDP.STAGING.market_ticks GROUP BY symbol) m
    ON p.symbol = m.symbol
  GROUP BY p.account_id;

-- Tasks are born SUSPENDED. Resume children first, then root:
ALTER TASK FUIDP.RAW.task_refresh_valuation RESUME;
ALTER TASK FUIDP.RAW.task_update_positions RESUME;











INSERT INTO FUIDP.RAW.trades_stream
SELECT 'TRD'||LPAD(98000+SEQ4(),8,'0'),'ACC'||LPAD(UNIFORM(1,200,RANDOM()),5,'0'),
       ARRAY_CONSTRUCT('AAPL','MSFT','NVDA')[UNIFORM(0,2,RANDOM())]::string,
       IFF(UNIFORM(0,1,RANDOM())=0,'BUY','SELL'),UNIFORM(1,500,RANDOM()),
       ROUND(UNIFORM(100,500,RANDOM()),2),CURRENT_TIMESTAMP()::timestamp_ntz,
       CURRENT_DATE()+2,'NYSE'
FROM TABLE(GENERATOR(ROWCOUNT=>300));

-- Within ~60-90s:
SELECT COUNT(*), MAX(updated_at) FROM FUIDP.ANALYTICS.positions;
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  SCHEDULED_TIME_RANGE_START=>DATEADD('minute',-15,CURRENT_TIMESTAMP())))
ORDER BY SCHEDULED_TIME DESC;


