# snowpark_lab.py
from snowflake.snowpark.types import FloatType
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, stddev, avg, count, sql_expr

session = Session.builder.configs({
    "account":   "mqgwzys-gg61299",
    "user":      "corporate",
    # lab only; prod = key-pair, as svc_kafka taught us
    "password":  "Prestige123$$/?",
    "role":      "ACCOUNTADMIN",
    "warehouse": "WH_ANALYTICS",
    "database":  "FUIDP", "schema": "RAW",
}).create()

# 1) DataFrame = lazy SQL pushdown. NOTHING computes yet:
trades = session.table("trades_large")
# cast price to FLOAT so AVG/STDDEV sum in floating point (range ~1.8e308),
# not exact NUMBER(38,0) which overflows at 1e38 on large groups.
price = col("price").cast(FloatType())
vol = (trades
       .group_by("symbol")
       .agg(count("*").alias("n_trades"),
            avg(price).alias("avg_price"),
            stddev(price).alias("price_vol")))   # the "risk metric"
print(vol.queries)        # <- the SQL Snowpark compiled. Show-and-tell moment.

# 2) NOW it runs - on the warehouse, not your laptop:
vol.show()

# 3) Persist results like any pipeline output:
vol.write.mode("overwrite").save_as_table("FUIDP.ANALYTICS.symbol_volatility")


# 4) A Python UDF living IN Snowflake (callable from plain SQL forever after):


def coefficient_of_variation(vol: float, mean: float) -> float:
    return None if not mean else vol / mean


session.udf.register(coefficient_of_variation, name="FUIDP.ANALYTICS.cv",
                     return_type=FloatType(), input_types=[FloatType(), FloatType()],
                     is_permanent=True, stage_location="@~", replace=True)
session.sql("""SELECT symbol, price_vol, avg_price,
                      FUIDP.ANALYTICS.cv(price_vol, avg_price) AS cv
               FROM FUIDP.ANALYTICS.symbol_volatility ORDER BY cv DESC""").show()
