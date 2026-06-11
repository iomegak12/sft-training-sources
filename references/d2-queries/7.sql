CREATE OR REPLACE TABLE daily_pnl (
  account_id STRING, trade_date DATE, realized_flow NUMBER(18,2),
  trade_count NUMBER, updated_at TIMESTAMP_NTZ);

CREATE OR REPLACE PROCEDURE compute_daily_pnl(p_date DATE)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  rows_merged INTEGER;
BEGIN
  MERGE INTO daily_pnl t
  USING (
    SELECT account_id, trade_ts::date AS trade_date,
           SUM(IFF(side='SELL', quantity*price, -quantity*price)) AS realized_flow,
           COUNT(*) AS trade_count
    FROM FUIDP.STAGING.trades_dedup
    WHERE trade_ts::date = :p_date
    GROUP BY 1,2
  ) s
  ON t.account_id = s.account_id AND t.trade_date = s.trade_date
  WHEN MATCHED THEN UPDATE SET realized_flow = s.realized_flow,
       trade_count = s.trade_count, updated_at = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT VALUES
       (s.account_id, s.trade_date, s.realized_flow, s.trade_count, CURRENT_TIMESTAMP());
  rows_merged := SQLROWCOUNT;
  RETURN 'P&L merged for ' || :p_date || ' — rows affected: ' || rows_merged;
END;
$$;

CALL compute_daily_pnl('2024-06-03');
SELECT * FROM daily_pnl ORDER BY realized_flow DESC LIMIT 10;