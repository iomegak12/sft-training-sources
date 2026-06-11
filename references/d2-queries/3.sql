USE SCHEMA FUIDP.ANALYTICS;

-- The ENTIRE positions pipeline, declaratively:
CREATE OR REPLACE DYNAMIC TABLE dt_positions
  TARGET_LAG = '1 minute'          -- training cadence; prod would be 5-15 min
  WAREHOUSE  = WH_INGEST
AS
SELECT account_id, symbol,
       SUM(IFF(side='BUY', quantity, -quantity)) AS net_quantity,
       MAX(trade_ts) AS last_trade_ts
FROM FUIDP.RAW.trades_stream
GROUP BY account_id, symbol;

-- Chain: valuation built ON the dynamic table (automatic dependency)
CREATE OR REPLACE DYNAMIC TABLE dt_portfolio_valuation
  TARGET_LAG = DOWNSTREAM           -- refresh when my consumers need me
  WAREHOUSE  = WH_INGEST
AS
SELECT p.account_id, SUM(p.net_quantity * m.price) AS market_value
FROM dt_positions p
JOIN (SELECT symbol, MAX_BY(price, event_ts) AS price
      FROM FUIDP.STAGING.market_ticks GROUP BY symbol) m
  ON p.symbol = m.symbol
GROUP BY p.account_id;




INSERT INTO FUIDP.RAW.trades_stream
SELECT 'TRD'||LPAD(98000+SEQ4(),8,'0'),'ACC'||LPAD(UNIFORM(1,200,RANDOM()),5,'0'),
       ARRAY_CONSTRUCT('AAPL','MSFT','NVDA')[UNIFORM(0,2,RANDOM())]::string,
       IFF(UNIFORM(0,1,RANDOM())=0,'BUY','SELL'),UNIFORM(1,500,RANDOM()),
       ROUND(UNIFORM(100,500,RANDOM()),2),CURRENT_TIMESTAMP()::timestamp_ntz,
       CURRENT_DATE()+2,'NYSE'
FROM TABLE(GENERATOR(ROWCOUNT=>300));


SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
ORDER BY REFRESH_START_TIME DESC LIMIT 10;
-- Snowsight: Data » FUIDP » ANALYTICS » dt_positions » Refresh History (visual DAG!)
SELECT COUNT(*) FROM dt_positions;