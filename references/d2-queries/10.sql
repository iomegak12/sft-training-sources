-- Bad join: condition doesn't tie t to a on a real key.
SELECT t.trade_id, a.advisor_id
FROM FUIDP.RAW.trades_large t
JOIN FUIDP.RAW.accounts a ON a.advisor_id = 'ADV'||LPAD(UNIFORM(1,20,RANDOM()),3,'0');




SELECT t.trade_id, a.advisor_id
FROM FUIDP.RAW.trades_large t
JOIN FUIDP.RAW.accounts a ON a.account_id = t.account_id;   -- sane: 1 account per trade