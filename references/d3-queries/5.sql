USE ROLE ACCOUNTADMIN;
SELECT ah.query_start_time, ah.user_name,
       bo.value:objectName::string AS object_name,
       col.value:columnName::string AS column_name
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah,
     LATERAL FLATTEN(ah.base_objects_accessed) bo,
     LATERAL FLATTEN(bo.value:columns) col
WHERE bo.value:objectName::string = 'FUIDP.RAW.ACCOUNTS'
  AND col.value:columnName::string IN ('SSN','EMAIL','PHONE')
  AND ah.query_start_time > DATEADD('day',-1,CURRENT_TIMESTAMP())
ORDER BY ah.query_start_time DESC;
-- "Who touched PII" = this query. (If lag hides today, demo on any FUIDP table touched yesterday.)



-- The safe rollout pattern, narrated:
CREATE NETWORK POLICY np_corp ALLOWED_IP_LIST=('203.0.113.0/24');
-- 1) Validate on a TEST USER first:  ALTER USER test_user SET NETWORK_POLICY='NP_CORP';
-- 2) Confirm the test user's access from the right/wrong network.
-- 3) Only then account-wide:         ALTER ACCOUNT SET NETWORK_POLICY='NP_CORP';
-- The lockout story: set a wrong CIDR account-wide and EVERYONE - including you - is out
-- (recovery requires support / a pre-allowed admin path). Hence: user-scope first, always.