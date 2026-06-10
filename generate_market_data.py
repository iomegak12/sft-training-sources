#!/usr/bin/env python3
"""
Atlas Market Data Generator
===========================
Generates synthetic-but-realistic equities & options market data for the
"Atlas" Snowflake Advanced training (client: Fidelity Investments).

Outputs (under ./data):
  Lab 1  ticks_history.csv         Historical equity ticks (pruning experiments)
  Lab 4  trades_batch_*.csv        Nightly venue trade files (bulk load + S3)
  Lab 5  option_chains_*.json      Nested option-chain payloads (semi-structured)
  Lab 6  ticks_intraday_*.csv      Small intraday files (Snowpipe auto-ingest drops)
  Lab 7  (producer script lives separately: kafka_exec_producer.py)

Design goals:
  - Moderate size: a few hundred thousand tick rows total, not gigabytes.
  - Realistic structure: OHLC-consistent ticks, venue codes, option Greeks,
    nested JSON that genuinely needs FLATTEN.
  - Deterministic: fixed seed so every student gets identical data.

Usage:
  python generate_market_data.py            # generate everything
  python generate_market_data.py --help
"""

import argparse
import json
import os
import random
from datetime import datetime, timedelta, date

import numpy as np
import pandas as pd

SEED = 20240115
random.seed(SEED)
np.random.seed(SEED)

DATA_DIR = os.path.join(os.path.dirname(__file__), ".", "data")
os.makedirs(DATA_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Reference data
# ---------------------------------------------------------------------------
SECURITIES = [
    # symbol, name, sector, ref_price
    ("FNF",  "Fidelity National Financial", "Financials",  52.40),
    ("AAPL", "Apple Inc.",                   "Technology", 188.20),
    ("MSFT", "Microsoft Corp.",              "Technology", 412.50),
    ("JPM",  "JPMorgan Chase & Co.",         "Financials", 195.10),
    ("XOM",  "Exxon Mobil Corp.",            "Energy",     104.75),
    ("TSLA", "Tesla Inc.",                   "Consumer",   178.30),
    ("NVDA", "NVIDIA Corp.",                 "Technology", 880.10),
    ("BRKB", "Berkshire Hathaway B",         "Financials", 408.60),
]

VENUES = ["NYSE", "NASDAQ", "CBOE", "ARCA", "BATS"]
VENUE_WEIGHTS = [0.34, 0.31, 0.10, 0.15, 0.10]

# Trading-day window (US market hours, UTC-ish for simplicity)
MARKET_OPEN = 9 * 3600 + 30 * 60      # 09:30
MARKET_CLOSE = 16 * 3600              # 16:00


def trading_days(start: date, n: int):
    """Yield n weekdays starting at `start`."""
    d = start
    count = 0
    while count < n:
        if d.weekday() < 5:  # Mon-Fri
            yield d
            count += 1
        d += timedelta(days=1)


# ---------------------------------------------------------------------------
# Lab 1: Historical ticks (the big-ish table we will prune)
# ---------------------------------------------------------------------------
def gen_ticks_history(n_days=60, ticks_per_symbol_per_day=400):
    """
    Build a historical tick table. We deliberately ORDER rows by symbol then
    time on write so the UNCLUSTERED load demonstrates poor natural clustering
    on TRADE_DATE (students then add a clustering key and re-measure pruning).
    """
    rows = []
    start = date(2024, 1, 2)
    for sym, name, sector, ref in SECURITIES:
        price = ref
        for d in trading_days(start, n_days):
            # random-walk intraday
            secs = np.sort(np.random.randint(MARKET_OPEN, MARKET_CLOSE,
                                             size=ticks_per_symbol_per_day))
            for s in secs:
                drift = np.random.normal(0, ref * 0.0008)
                price = max(0.5, price + drift)
                spread = max(0.01, price * 0.0002)
                bid = round(price - spread / 2, 2)
                ask = round(price + spread / 2, 2)
                size = int(np.random.lognormal(4.2, 1.0))
                venue = random.choices(VENUES, weights=VENUE_WEIGHTS)[0]
                ts = datetime(d.year, d.month, d.day) + timedelta(seconds=int(s))
                rows.append((
                    sym, d.isoformat(), ts.isoformat(sep=" "),
                    round(price, 2), bid, ask, size, venue
                ))
    df = pd.DataFrame(rows, columns=[
        "SYMBOL", "TRADE_DATE", "TICK_TS", "LAST_PRICE",
        "BID", "ASK", "TRADE_SIZE", "VENUE"
    ])
    # Sort by SYMBOL first (NOT by date) -> poor pruning on TRADE_DATE initially
    df = df.sort_values(["SYMBOL", "TICK_TS"]).reset_index(drop=True)
    out = os.path.join(DATA_DIR, "ticks_history.csv")
    df.to_csv(out, index=False)
    print(f"[Lab 1] ticks_history.csv         rows={len(df):>8,}  -> {out}")
    return df


# ---------------------------------------------------------------------------
# Lab 4: Nightly venue trade batch files (bulk load + S3)
# ---------------------------------------------------------------------------
def gen_trades_batch(n_days=5, trades_per_day=8000):
    start = date(2024, 4, 1)
    paths = []
    trade_id = 1_000_000
    for d in trading_days(start, n_days):
        rows = []
        for _ in range(trades_per_day):
            sym, name, sector, ref = random.choice(SECURITIES)
            secs = np.random.randint(MARKET_OPEN, MARKET_CLOSE)
            ts = datetime(d.year, d.month, d.day) + timedelta(seconds=int(secs))
            price = round(ref * (1 + np.random.normal(0, 0.01)), 2)
            qty = int(np.random.lognormal(4.5, 1.1))
            side = random.choice(["BUY", "SELL"])
            venue = random.choices(VENUES, weights=VENUE_WEIGHTS)[0]
            trade_id += 1
            rows.append((trade_id, ts.isoformat(sep=" "), sym, side,
                         price, qty, venue))
        df = pd.DataFrame(rows, columns=[
            "TRADE_ID", "EXEC_TS", "SYMBOL", "SIDE",
            "PRICE", "QUANTITY", "VENUE"
        ])
        fname = f"trades_batch_{d.isoformat()}.csv"
        out = os.path.join(DATA_DIR, fname)
        df.to_csv(out, index=False)
        paths.append(out)
    print(f"[Lab 4] trades_batch_*.csv        files={len(paths):>8}  "
          f"(~{trades_per_day:,} rows each)")
    return paths


# ---------------------------------------------------------------------------
# Lab 5: Nested option-chain JSON (semi-structured)
# ---------------------------------------------------------------------------
def gen_option_chains(n_underlyings=5, expiries=3, strikes=8):
    """
    Produce a deeply nested payload that genuinely requires FLATTEN:
      underlying -> expirations[] -> { calls[], puts[] } -> contract {greeks{}}
    """
    chains = []
    for sym, name, sector, ref in SECURITIES[:n_underlyings]:
        expirations = []
        base_exp = date(2024, 5, 17)
        for e in range(expiries):
            exp = base_exp + timedelta(days=28 * e)
            strike_grid = np.linspace(ref * 0.9, ref * 1.1, strikes).round(1)
            calls, puts = [], []
            for k in strike_grid:
                moneyness = ref / k
                for opt_type, bucket in (("CALL", calls), ("PUT", puts)):
                    iv = round(abs(np.random.normal(0.28, 0.06)), 4)
                    delta = round(
                        (moneyness - 1) * 2 if opt_type == "CALL"
                        else (1 - moneyness) * 2, 4)
                    delta = max(-1.0, min(1.0, delta))
                    bucket.append({
                        "contractId": f"{sym}{exp.strftime('%y%m%d')}"
                                      f"{opt_type[0]}{int(k*1000):08d}",
                        "strike": float(k),
                        "type": opt_type,
                        "lastPrice": round(abs(np.random.normal(
                            max(0.05, (ref - k) if opt_type == "CALL"
                                else (k - ref)), 1.5)), 2),
                        "bid": round(np.random.uniform(0.1, 5), 2),
                        "ask": round(np.random.uniform(5, 10), 2),
                        "volume": int(np.random.lognormal(5, 1.2)),
                        "openInterest": int(np.random.lognormal(6, 1.0)),
                        "greeks": {
                            "delta": delta,
                            "gamma": round(abs(np.random.normal(0.05, 0.02)), 4),
                            "theta": round(-abs(np.random.normal(0.03, 0.01)), 4),
                            "vega": round(abs(np.random.normal(0.12, 0.04)), 4),
                            "impliedVol": iv,
                        },
                    })
            expirations.append({
                "expirationDate": exp.isoformat(),
                "daysToExpiry": (exp - base_exp).days,
                "contracts": {"calls": calls, "puts": puts},
            })
        chains.append({
            "underlying": {
                "symbol": sym,
                "name": name,
                "sector": sector,
                "refPrice": ref,
            },
            "snapshotTs": datetime(2024, 4, 19, 20, 0, 0).isoformat(),
            "expirations": expirations,
        })
    # Write as one NDJSON-ish file (one object per underlying) + one combined
    out = os.path.join(DATA_DIR, "option_chains_2024-04-19.json")
    with open(out, "w") as f:
        for c in chains:
            f.write(json.dumps(c) + "\n")
    n_contracts = sum(
        len(e["contracts"]["calls"]) + len(e["contracts"]["puts"])
        for c in chains for e in c["expirations"])
    print(f"[Lab 5] option_chains_*.json      objects={len(chains):>6}  "
          f"contracts={n_contracts:,}  -> {out}")
    return out


# ---------------------------------------------------------------------------
# Lab 6: Small intraday tick files for Snowpipe auto-ingest drops
# ---------------------------------------------------------------------------
def gen_intraday_drops(n_files=6, rows_per_file=2000):
    paths = []
    d = date(2024, 4, 22)
    base = datetime(d.year, d.month, d.day, 9, 30, 0)
    for i in range(n_files):
        rows = []
        window_start = base + timedelta(minutes=i * 60)
        for _ in range(rows_per_file):
            sym, name, sector, ref = random.choice(SECURITIES)
            offset = np.random.randint(0, 3600)
            ts = window_start + timedelta(seconds=int(offset))
            price = round(ref * (1 + np.random.normal(0, 0.006)), 2)
            size = int(np.random.lognormal(4.0, 1.0))
            venue = random.choices(VENUES, weights=VENUE_WEIGHTS)[0]
            rows.append((sym, ts.isoformat(sep=" "), price, size, venue))
        df = pd.DataFrame(rows, columns=[
            "SYMBOL", "TICK_TS", "LAST_PRICE", "TRADE_SIZE", "VENUE"])
        fname = f"ticks_intraday_{d.isoformat()}_{i:02d}.csv"
        out = os.path.join(DATA_DIR, fname)
        df.to_csv(out, index=False)
        paths.append(out)
    print(f"[Lab 6] ticks_intraday_*.csv      files={len(paths):>8}  "
          f"({rows_per_file:,} rows each)")
    return paths


def summary():
    total = 0
    print("\n" + "=" * 60)
    print("DATA SET SUMMARY (under ./data)")
    print("=" * 60)
    for f in sorted(os.listdir(DATA_DIR)):
        fp = os.path.join(DATA_DIR, f)
        sz = os.path.getsize(fp)
        total += sz
        print(f"  {f:<38} {sz/1024:>9,.1f} KB")
    print("-" * 60)
    print(f"  {'TOTAL':<38} {total/1024/1024:>9,.2f} MB")


def main():
    ap = argparse.ArgumentParser(description="Generate Atlas synthetic market data")
    ap.add_argument("--quick", action="store_true",
                    help="smaller volumes for a fast smoke test")
    args = ap.parse_args()

    if args.quick:
        gen_ticks_history(n_days=10, ticks_per_symbol_per_day=100)
        gen_trades_batch(n_days=2, trades_per_day=1000)
        gen_option_chains()
        gen_intraday_drops(n_files=2, rows_per_file=300)
    else:
        gen_ticks_history()
        gen_trades_batch()
        gen_option_chains()
        gen_intraday_drops()
    summary()


if __name__ == "__main__":
    main()
