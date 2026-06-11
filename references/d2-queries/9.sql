ALTER WAREHOUSE WH_ANALYTICS SET WAREHOUSE_SIZE='XSMALL';
ALTER SESSION SET USE_CACHED_RESULT = FALSE;   -- so re-runs actually recompute
SELECT account_id, symbol, trade_ts, price,
       ROW_NUMBER() OVER (ORDER BY price DESC, trade_ts, trade_id) AS rn
FROM FUIDP.RAW.trades_large
ORDER BY price DESC, trade_ts
LIMIT 100000;





ALTER WAREHOUSE WH_ANALYTICS SET WAREHOUSE_SIZE='MEDIUM';
SELECT account_id, symbol, trade_ts, price,
       ROW_NUMBER() OVER (ORDER BY price DESC, trade_ts, trade_id) AS rn
FROM FUIDP.RAW.trades_large
ORDER BY price DESC, trade_ts
LIMIT 100000;



ALTER WAREHOUSE WH_ANALYTICS SET WAREHOUSE_SIZE='SMALL';
ALTER SESSION UNSET USE_CACHED_RESULT;   -- restore default caching