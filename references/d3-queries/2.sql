USE ROLE ACCOUNTADMIN;

-- 1) The exposure contract: a SECURE view, PII-free by construction:
CREATE OR REPLACE SECURE VIEW FUIDP.ANALYTICS.sv_auditor_valuation AS
SELECT a.account_id,                      -- id, not name/ssn/email
       a.segment, a.advisor_id,
       v.market_value,
       CURRENT_DATE() AS as_of_date
FROM FUIDP.ANALYTICS.portfolio_valuation v
JOIN FUIDP.RAW.accounts a USING (account_id);

-- 2) The share + grants (database & schema usage, then the view):
CREATE OR REPLACE SHARE fuidp_auditor_share
  COMMENT='Monthly valuation exposure for external audit';
GRANT USAGE ON DATABASE FUIDP TO SHARE fuidp_auditor_share;
GRANT USAGE ON SCHEMA FUIDP.ANALYTICS TO SHARE fuidp_auditor_share;
GRANT SELECT ON VIEW FUIDP.ANALYTICS.sv_auditor_valuation TO SHARE fuidp_auditor_share;

-- 3) Add the consumer (instructor provides the 2nd account identifier):
ALTER SHARE fuidp_auditor_share ADD ACCOUNTS = wzluxrr.kh13461;
SHOW SHARES LIKE 'fuidp_auditor_share';








# CONSUMER SIDE

SHOW SHARES;        -- inbound shares from every attendee appear
CREATE DATABASE fuidp_from_attendee FROM SHARE mqgwzys.gg61299.fuidp_auditor_share;
SELECT * FROM fuidp_from_attendee.ANALYTICS.sv_auditor_valuation LIMIT 10;  -- LIVE data


