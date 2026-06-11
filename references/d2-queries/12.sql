-- BEFORE:
SELECT * FROM FUIDP.RAW.trades_large WHERE account_id='ACC00042';  -- note time + partitions
ALTER TABLE FUIDP.RAW.trades_large ADD SEARCH OPTIMIZATION ON EQUALITY(account_id);
SHOW TABLES LIKE 'trades_large';   -- search_optimization=ON; wait for active build
-- AFTER: rerun the lookup; compare partitions scanned + elapsed.