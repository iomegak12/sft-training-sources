-- BEFORE: capture the baseline from Lab 13's pathology-1 profile numbers.
ALTER TABLE FUIDP.RAW.trades_large CLUSTER BY (trade_ts);

-- Reclustering is background; give it a few minutes, monitor:
SELECT SYSTEM$CLUSTERING_INFORMATION('FUIDP.RAW.trades_large','(trade_ts)');

-- AFTER (run once average_depth has dropped):
SELECT COUNT(*), AVG(price) FROM FUIDP.RAW.trades_large
WHERE trade_ts BETWEEN '2024-06-10' AND '2024-06-12';
-- Profile: partitions scanned should now be a small fraction of total.