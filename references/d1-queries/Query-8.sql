USE WAREHOUSE ATLAS_ANALYTICS_WH;

USE SCHEMA FIDELITY_ATLAS.ANALYTICS;


WITH quote_activity AS (
  SELECT s.SYMBOL, COUNT(*) AS quote_ticks, AVG(q.SPREAD) AS avg_spread
  FROM FACT_QUOTES q JOIN DIM_SECURITY s USING (SECURITY_KEY)
  GROUP BY s.SYMBOL
),
trade_activity AS (
  SELECT s.SYMBOL, COUNT(*) AS trades, SUM(t.NOTIONAL) AS traded_notional
  FROM FACT_TRADES t JOIN DIM_SECURITY s USING (SECURITY_KEY)
  GROUP BY s.SYMBOL
),
exec_activity AS (
  SELECT s.SYMBOL, COUNT(*) AS live_execs,
         SUM(IFF(e.FILL_STATUS='FILLED',1,0)) AS filled
  FROM FACT_EXECUTIONS e JOIN DIM_SECURITY s USING (SECURITY_KEY)
  GROUP BY s.SYMBOL
),
options_activity AS (
  SELECT s.SYMBOL, COUNT(*) AS option_contracts, AVG(o.IMPLIED_VOL) AS avg_iv
  FROM FACT_OPTION_QUOTES o JOIN DIM_SECURITY s USING (SECURITY_KEY)
  GROUP BY s.SYMBOL
)
SELECT
  ds.SYMBOL, ds.COMPANY_NAME, ds.SECTOR,
  q.quote_ticks, ROUND(q.avg_spread,4) AS avg_spread,
  t.trades, t.traded_notional,
  x.live_execs, x.filled,
  o.option_contracts, ROUND(o.avg_iv,4) AS avg_implied_vol
FROM DIM_SECURITY ds
LEFT JOIN quote_activity   q USING (SYMBOL)
LEFT JOIN trade_activity   t USING (SYMBOL)
LEFT JOIN exec_activity    x USING (SYMBOL)
LEFT JOIN options_activity o USING (SYMBOL)
ORDER BY t.traded_notional DESC NULLS LAST;