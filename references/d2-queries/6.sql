-- Manufacture duplicates first:
INSERT INTO FUIDP.RAW.trades SELECT * FROM FUIDP.RAW.trades LIMIT 50;
SELECT COUNT(*), COUNT(DISTINCT trade_id) FROM FUIDP.RAW.trades;   -- gap = 50 dups

-- One clause, no temp tables:
CREATE OR REPLACE TABLE FUIDP.STAGING.trades_dedup AS
SELECT * FROM FUIDP.RAW.trades
QUALIFY ROW_NUMBER() OVER (PARTITION BY trade_id ORDER BY trade_ts DESC) = 1;
SELECT COUNT(*), COUNT(DISTINCT trade_id) FROM FUIDP.STAGING.trades_dedup;  -- equal