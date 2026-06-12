USE ROLE ACCOUNTADMIN; USE SCHEMA FUIDP.RAW;

CREATE OR REPLACE MASKING POLICY mp_ssn AS (val STRING) RETURNS STRING ->
  CASE WHEN CURRENT_ROLE() IN ('COMPLIANCE','ACCOUNTADMIN') THEN val
       ELSE '***-**-****' END;

CREATE OR REPLACE MASKING POLICY mp_email AS (val STRING) RETURNS STRING ->
  CASE WHEN CURRENT_ROLE() IN ('COMPLIANCE','ACCOUNTADMIN') THEN val
       ELSE REGEXP_REPLACE(val,'^[^@]+','*****') END;   -- *****@example.com

ALTER TABLE accounts MODIFY COLUMN ssn   SET MASKING POLICY mp_ssn;
ALTER TABLE accounts MODIFY COLUMN email SET MASKING POLICY mp_email;


CREATE OR REPLACE TABLE FUIDP.RAW.advisor_user_map (snowflake_user STRING, advisor_id STRING);
INSERT INTO advisor_user_map VALUES (CURRENT_USER(), 'ADV001');

CREATE OR REPLACE ROW ACCESS POLICY rap_advisor_book AS (adv_id STRING) RETURNS BOOLEAN ->
  CURRENT_ROLE() IN ('COMPLIANCE','ANALYST','ENGINEER','ACCOUNTADMIN')
  OR EXISTS (SELECT 1 FROM FUIDP.RAW.advisor_user_map m
             WHERE m.snowflake_user = CURRENT_USER() AND m.advisor_id = adv_id);

ALTER TABLE accounts ADD ROW ACCESS POLICY rap_advisor_book ON (advisor_id);






USE ROLE COMPLIANCE; SELECT account_id, customer_name, ssn, email, advisor_id FROM FUIDP.RAW.accounts LIMIT 5;
USE ROLE ANALYST;    SELECT account_id, customer_name, ssn, email, advisor_id FROM FUIDP.RAW.accounts LIMIT 5;
USE ROLE ADVISOR;    SELECT account_id, customer_name, ssn, email, advisor_id FROM FUIDP.RAW.accounts LIMIT 5;
USE ROLE ACCOUNTADMIN;
-- Compliance: clear SSNs, all rows. Analyst: masked SSNs, all rows.
-- Advisor: masked SSNs, ONLY ADV001's clients. One table, three truths.





CREATE TAG IF NOT EXISTS FUIDP.RAW.pii_type;
CREATE OR REPLACE MASKING POLICY mp_pii_generic AS (val STRING) RETURNS STRING ->
  CASE WHEN CURRENT_ROLE() IN ('COMPLIANCE','ACCOUNTADMIN') THEN val ELSE '<REDACTED>' END;
ALTER TAG FUIDP.RAW.pii_type SET MASKING POLICY mp_pii_generic;

-- The future-proofing: a NEW PII column ships...
ALTER TABLE accounts ADD COLUMN phone STRING;
UPDATE accounts SET phone='617-555-01'||UNIFORM(10,99,RANDOM());
-- ...and is protected the moment it's TAGGED (no per-column policy work):
ALTER TABLE accounts MODIFY COLUMN phone SET TAG FUIDP.RAW.pii_type='PHONE';
USE ROLE ANALYST; SELECT phone FROM FUIDP.RAW.accounts LIMIT 3;   -- <REDACTED>
USE ROLE ACCOUNTADMIN;