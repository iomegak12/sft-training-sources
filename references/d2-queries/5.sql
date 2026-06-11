USE SCHEMA FUIDP.ANALYTICS; USE WAREHOUSE WH_ANALYTICS;
SELECT account_id, symbol, trade_ts, side, quantity, price,
       SUM(IFF(side='BUY', quantity*price, -quantity*price))
         OVER (PARTITION BY account_id, symbol ORDER BY trade_ts
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_cost_basis
FROM FUIDP.RAW.trades
WHERE account_id = 'ACC00042'
ORDER BY symbol, trade_ts;