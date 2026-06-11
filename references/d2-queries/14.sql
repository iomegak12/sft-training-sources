-- Result cache: run any Lab 14 aggregate twice, identical text.
SELECT symbol, COUNT(*), AVG(price) FROM FUIDP.RAW.trades_large GROUP BY symbol;
-- Rerun verbatim: ~ms, 0 partitions. Profile says RESULT REUSE.
-- Now defeat it the way dashboards accidentally do:
SELECT symbol, COUNT(*), AVG(price), CURRENT_TIMESTAMP() FROM FUIDP.RAW.trades_large GROUP BY symbol;
-- Full recompute. One needless non-deterministic column = cache gone.