USE SCHEMA FIDELITY_ATLAS.RAW;

CREATE OR REPLACE FILE FORMAT FF_JSON TYPE=JSON STRIP_OUTER_ARRAY=FALSE;


CREATE OR REPLACE TABLE RAW_OPTIONS (
  V          VARIANT,
  LOADED_AT  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE STAGE ATLAS_JSON_STAGE FILE_FORMAT=FF_JSON;


COPY INTO RAW_OPTIONS (V)
FROM @ATLAS_JSON_STAGE/option_chains_2024-04-19.json
FILE_FORMAT = FF_JSON;

SELECT COUNT(*) AS underlyings FROM RAW_OPTIONS;   -- 5


SELECT V:underlying:symbol::string  AS symbol,
       V:underlying:sector::string  AS sector,
       V:snapshotTs::timestamp_ntz  AS snapshot_ts,
       ARRAY_SIZE(V:expirations)     AS n_expirations
FROM RAW_OPTIONS;


SELECT V:underlying:symbol::string AS symbol,
       e.value:expirationDate::date AS expiration,
       e.value:daysToExpiry::int    AS dte,
       ARRAY_SIZE(e.value:contracts:calls) AS n_calls,
       ARRAY_SIZE(e.value:contracts:puts)  AS n_puts
FROM RAW_OPTIONS,
     LATERAL FLATTEN(input => V:expirations) e;


INSERT INTO FIDELITY_ATLAS.ANALYTICS.FACT_OPTION_QUOTES
 (SECURITY_KEY, DATE_KEY, CONTRACT_ID, OPT_TYPE, STRIKE, EXPIRATION,
  DAYS_TO_EXPIRY, LAST_PRICE, BID, ASK, VOLUME, OPEN_INTEREST,
  DELTA, GAMMA, THETA, VEGA, IMPLIED_VOL)
SELECT
  s.SECURITY_KEY,
  TO_NUMBER(TO_CHAR(r.V:snapshotTs::date,'YYYYMMDD')),
  c.value:contractId::string,
  c.value:type::string,
  c.value:strike::number(12,2),
  e.value:expirationDate::date,
  e.value:daysToExpiry::int,
  c.value:lastPrice::number(12,2),
  c.value:bid::number(12,2),
  c.value:ask::number(12,2),
  c.value:volume::number,
  c.value:openInterest::number,
  c.value:greeks:delta::number(8,4),
  c.value:greeks:gamma::number(8,4),
  c.value:greeks:theta::number(8,4),
  c.value:greeks:vega::number(8,4),
  c.value:greeks:impliedVol::number(8,4)
FROM RAW_OPTIONS r
JOIN FIDELITY_ATLAS.ANALYTICS.DIM_SECURITY s
     ON s.SYMBOL = r.V:underlying:symbol::string,
     LATERAL FLATTEN(input => r.V:expirations) e,
     LATERAL FLATTEN(input =>
        ARRAY_CAT(e.value:contracts:calls, e.value:contracts:puts)) c;

SELECT OPT_TYPE, COUNT(*) FROM FIDELITY_ATLAS.ANALYTICS.FACT_OPTION_QUOTES
GROUP BY OPT_TYPE;        