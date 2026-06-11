CREATE OR REPLACE MATERIALIZED VIEW FUIDP.ANALYTICS.mv_symbol_summary AS
SELECT symbol, COUNT(*) AS trade_count, SUM(quantity) AS total_qty, AVG(price) AS avg_price
FROM FUIDP.RAW.trades_large GROUP BY symbol;

SELECT * FROM FUIDP.ANALYTICS.mv_symbol_summary;        -- instant
-- vs the same aggregate on the base table: compare profiles.