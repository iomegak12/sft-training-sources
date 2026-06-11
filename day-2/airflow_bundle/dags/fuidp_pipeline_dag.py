"""
fuidp_pipeline_dag.py — Lab 11 skeleton
=======================================
The Fidelity FUIDP batch orchestration DAG. Three tasks are COMPLETE,
three are marked TODO — you complete them in Lab 11 (hints inline).

Pipeline shape:
  check_freshness >> transform_positions >> dq_gate >> refresh_analytics >> notify

Requires an Airflow connection:  Conn Id = snowflake_fuidp  (Conn Type: Snowflake)
"""
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

SNOWFLAKE_CONN_ID = "snowflake_fuidp"

default_args = {
    "owner": "fuidp",
    "retries": 2,                       # Experiment (a): retry semantics
    "retry_delay": timedelta(seconds=30),
}

# ----------------------------------------------------------------------------
# SQL blocks
# ----------------------------------------------------------------------------

# COMPLETE — freshness check: fail loudly if no trades landed in last 24h of
# data we have (training data is static, so we check the table is non-empty
# and not silently truncated).
SQL_CHECK_FRESHNESS = """
SELECT IFF(COUNT(*) >= 1500, 1, 1/0)   -- divide-by-zero = deliberate failure
FROM FUIDP.RAW.trades_stream;
"""

# TODO #1 — transform_positions: the Lab 9 MERGE, consuming the pipeline stream.
# HINT: paste the MERGE from Lab 9's task_update_positions body here verbatim
# (the stream FUIDP.RAW.strm_trades_pipeline must exist — Lab 9 created it).
SQL_TRANSFORM_POSITIONS = """
-- TODO: MERGE INTO FUIDP.ANALYTICS.positions ... USING (SELECT ... FROM
--       FUIDP.RAW.strm_trades_pipeline ...) ...
SELECT 'replace me' ;
"""

# TODO #2 — dq_gate: three checks; each must FAIL THE TASK if violated.
# HINT: the 1/0 trick above, or HAVING clauses that return no rows + a guard.
#   check 1: FUIDP.ANALYTICS.positions row count > 0
#   check 2: zero NULL account_id in positions
#   check 3: zero trades with trade_ts in the future
SQL_DQ_GATE = """
-- TODO: three statements; make each blow up when its invariant is violated.
SELECT 'replace me';
"""

# TODO #3 — refresh_analytics: rebuild portfolio_valuation (Lab 9 child task SQL).
SQL_REFRESH_ANALYTICS = """
-- TODO: CREATE OR REPLACE TABLE FUIDP.ANALYTICS.portfolio_valuation AS ...
SELECT 'replace me';
"""

# ----------------------------------------------------------------------------
# DAG
# ----------------------------------------------------------------------------
with DAG(
    dag_id="fuidp_pipeline",
    description="FUIDP: freshness check -> transform -> DQ gate -> analytics refresh -> notify",
    start_date=datetime(2024, 6, 1),
    schedule=None,                      # manual trigger for the lab; stretch: '*/10 * * * *'
    catchup=False,
    default_args=default_args,
    tags=["fuidp", "training"],
) as dag:

    check_freshness = SQLExecuteQueryOperator(
        task_id="check_freshness",
        conn_id=SNOWFLAKE_CONN_ID,
        sql=SQL_CHECK_FRESHNESS,
    )

    transform_positions = SQLExecuteQueryOperator(
        task_id="transform_positions",
        conn_id=SNOWFLAKE_CONN_ID,
        sql=SQL_TRANSFORM_POSITIONS,
    )

    dq_gate = SQLExecuteQueryOperator(
        task_id="dq_gate",
        conn_id=SNOWFLAKE_CONN_ID,
        sql=SQL_DQ_GATE,
    )

    refresh_analytics = SQLExecuteQueryOperator(
        task_id="refresh_analytics",
        conn_id=SNOWFLAKE_CONN_ID,
        sql=SQL_REFRESH_ANALYTICS,
    )

    # COMPLETE — stand-in for a Slack/email notification (stretch: replace it)
    notify = BashOperator(
        task_id="notify",
        bash_command='echo "FUIDP pipeline run complete: $(date -u +%Y-%m-%dT%H:%M:%SZ)"',
    )

    check_freshness >> transform_positions >> dq_gate >> refresh_analytics >> notify
