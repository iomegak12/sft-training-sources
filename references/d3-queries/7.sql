GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PUBLIC;   -- lab-wide; scope tighter in prod





USE SCHEMA FUIDP.STAGING; USE WAREHOUSE WH_ANALYTICS;

CREATE OR REPLACE TABLE trade_notes (note_id INT, account_id STRING, note STRING);
INSERT INTO trade_notes VALUES
 (1,'ACC00042','Client called very upset about the TSLA position losses, wants to discuss moving to index funds.'),
 (2,'ACC00007','Routine rebalance executed per quarterly plan. Client satisfied with allocation.'),
 (3,'ACC00115','Client requests increasing 401k contribution and asked about FXAIX expense ratio.'),
 (4,'ACC00033','Urgent: client believes an unauthorized trade occurred on Tuesday. Escalate to compliance.');

SELECT note_id,
       SNOWFLAKE.CORTEX.SENTIMENT(note)                              AS sentiment,
       AI_CLASSIFY(note, ['complaint','routine','inquiry','escalation']):labels[0]::string AS category,
       SNOWFLAKE.CORTEX.SUMMARIZE(note)                              AS summary
FROM trade_notes;





USE SCHEMA FUIDP.ANALYTICS;

CREATE OR REPLACE SEMANTIC VIEW sv_portfolio_semantics
  TABLES (
    positions AS FUIDP.ANALYTICS.POSITIONS
      PRIMARY KEY (account_id, symbol)
      WITH SYNONYMS ('holdings','book')
      COMMENT = 'Current net holdings per account and symbol',
    accounts AS FUIDP.RAW.ACCOUNTS
      PRIMARY KEY (account_id)
      WITH SYNONYMS ('clients','customers')
      COMMENT = 'Client accounts; PII governed by masking policies',
    pnl AS FUIDP.ANALYTICS.DAILY_PNL
      PRIMARY KEY (account_id, trade_date)
      WITH SYNONYMS ('profit and loss','performance')
      COMMENT = 'Daily realized cash flow per account'
  )
  RELATIONSHIPS (
    positions (account_id) REFERENCES accounts,
    pnl       (account_id) REFERENCES accounts
  )
  DIMENSIONS (
    accounts.segment     AS segment     COMMENT='Client segment: RETAIL, WEALTH, INSTITUTIONAL, RETIREMENT_401K',
    accounts.advisor_id  AS advisor_id  COMMENT='Servicing advisor',
    positions.symbol     AS symbol      COMMENT='Security ticker',
    pnl.trade_date       AS trade_date  COMMENT='Trading day'
  )
  METRICS (
    positions.total_quantity AS SUM(positions.net_quantity) COMMENT='Total net shares held',
    pnl.total_flow           AS SUM(pnl.realized_flow)      COMMENT='Total realized P&L cash flow',
    accounts.client_count    AS COUNT(DISTINCT accounts.account_id) COMMENT='Number of clients'
  )
  COMMENT = 'FUIDP portfolio semantic model for Cortex Analyst';

-- Prove the model answers structured questions directly:
SELECT * FROM SEMANTIC_VIEW(sv_portfolio_semantics
  METRICS pnl.total_flow  DIMENSIONS accounts.segment);




-- Ensure the personas can use the model's objects (Lab 18 grants cover the tables;
-- grant the semantic view):
GRANT SELECT ON SEMANTIC VIEW FUIDP.ANALYTICS.sv_portfolio_semantics TO ROLE ADVISOR;
GRANT SELECT ON SEMANTIC VIEW FUIDP.ANALYTICS.sv_portfolio_semantics TO ROLE COMPLIANCE;



