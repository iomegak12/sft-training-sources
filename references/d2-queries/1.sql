USE SCHEMA FUIDP.RAW; USE WAREHOUSE WH_INGEST;

-- The bookmark:
CREATE OR REPLACE STREAM strm_trades ON TABLE trades_stream;

-- Nothing has changed since creation:
SELECT COUNT(*) FROM strm_trades;        -- 0

-- Simulate new trades arriving (stand-in for Snowpipe):
INSERT INTO trades_stream
SELECT 'TRD'||LPAD(99000+SEQ4(),8,'0'), 'ACC'||LPAD(UNIFORM(1,200,RANDOM()),5,'0'),
       'AAPL','BUY',UNIFORM(1,500,RANDOM()),195.50,
       CURRENT_TIMESTAMP()::timestamp_ntz, CURRENT_DATE()+2,'NASDAQ'
FROM TABLE(GENERATOR(ROWCOUNT=>500));

-- The stream sees exactly the delta:
SELECT COUNT(*) FROM strm_trades;        -- 500
SELECT METADATA$ACTION, METADATA$ISUPDATE, trade_id FROM strm_trades LIMIT 5;