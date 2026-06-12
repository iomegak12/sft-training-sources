USE SCHEMA FUIDP.ANALYTICS; USE WAREHOUSE WH_ANALYTICS;

-- 1) The disaster (note the query_id Snowsight shows after running!):
UPDATE positions SET net_quantity = 0;          -- the WHERE-less Friday special
SELECT MIN(net_quantity), MAX(net_quantity) FROM positions;   -- all zero. Panic.

-- 2) Grab the destructive statement's query id:
SET qid = (SELECT QUERY_ID FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
           WHERE QUERY_TEXT ILIKE 'UPDATE positions SET net_quantity = 0%'
           ORDER BY START_TIME DESC LIMIT 1);

-- 3) Surgical recovery: the table AS IT WAS immediately BEFORE that statement:
CREATE OR REPLACE TABLE positions AS
SELECT * FROM positions BEFORE(STATEMENT => $qid);
SELECT MIN(net_quantity), MAX(net_quantity) FROM positions;   -- restored. Seconds.

-- 4) UNDROP:
DROP TABLE positions;
UNDROP TABLE positions;          -- back, with all history

-- 5) Zero-copy dev environment:
CREATE SCHEMA IF NOT EXISTS FUIDP.DEV_TEST;
CREATE OR REPLACE TRANSIENT TABLE FUIDP.DEV_TEST.trades_large CLONE FUIDP.RAW.trades_large;
-- Instant, despite 5M rows. Mutate the clone; prod untouched:
DELETE FROM FUIDP.DEV_TEST.trades_large WHERE symbol='AAPL';
SELECT (SELECT COUNT(*) FROM FUIDP.DEV_TEST.trades_large) AS clone_ct,
       (SELECT COUNT(*) FROM FUIDP.RAW.trades_large)      AS prod_ct;