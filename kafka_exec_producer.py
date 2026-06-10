#!/usr/bin/env python3
"""
Atlas Live Execution Feed -> Kafka Producer  (Lab 7)
===================================================
Publishes synthetic order-execution events to a Kafka topic. The Snowflake
Kafka connector (Snowpipe Streaming mode) consumes the topic and lands rows
in RAW.RAW_EXECUTIONS.

Run AFTER the Docker Kafka stack is up (see Lab 7 docker-compose).

  pip install kafka-python
  python kafka_exec_producer.py --bootstrap localhost:9092 \
      --topic atlas.executions --rate 20 --count 2000

Each message:
  key   = SYMBOL                      (so a symbol's events keep order/partition)
  value = JSON execution event
"""
import argparse, json, random, time, uuid
from datetime import datetime, timezone

try:
    from kafka import KafkaProducer
except ImportError:
    raise SystemExit("Install dependency first:  pip install kafka-python")

SECURITIES = [
    ("FNF", 52.40), ("AAPL", 188.20), ("MSFT", 412.50), ("JPM", 195.10),
    ("XOM", 104.75), ("TSLA", 178.30), ("NVDA", 880.10), ("BRKB", 408.60),
]
VENUES = ["NYSE", "NASDAQ", "CBOE", "ARCA", "BATS"]
ORDER_TYPES = ["MARKET", "LIMIT", "STOP", "STOP_LIMIT"]


def make_event():
    sym, ref = random.choice(SECURITIES)
    price = round(ref * (1 + random.gauss(0, 0.01)), 2)
    return {
        "eventId": str(uuid.uuid4()),
        "eventTs": datetime.now(timezone.utc).isoformat(),
        "symbol": sym,
        "side": random.choice(["BUY", "SELL"]),
        "orderType": random.choice(ORDER_TYPES),
        "price": price,
        "quantity": int(abs(random.gauss(300, 200))) + 1,
        "venue": random.choice(VENUES),
        "trader": f"DESK{random.randint(1, 12):02d}",
        "fillStatus": random.choices(
            ["FILLED", "PARTIAL", "NEW"], weights=[0.75, 0.15, 0.10])[0],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bootstrap", default="localhost:9092")
    ap.add_argument("--topic", default="atlas.executions")
    ap.add_argument("--rate", type=float, default=20, help="events/second")
    ap.add_argument("--count", type=int, default=2000, help="total events")
    args = ap.parse_args()

    producer = KafkaProducer(
        bootstrap_servers=args.bootstrap,
        key_serializer=lambda k: k.encode("utf-8"),
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        linger_ms=50,
        acks="all",
    )
    interval = 1.0 / args.rate if args.rate > 0 else 0
    sent = 0
    print(f"Producing {args.count} events to '{args.topic}' "
          f"@ {args.rate}/s via {args.bootstrap} ...")
    try:
        for _ in range(args.count):
            ev = make_event()
            producer.send(args.topic, key=ev["symbol"], value=ev)
            sent += 1
            if sent % 100 == 0:
                print(f"  sent {sent:,}")
            if interval:
                time.sleep(interval)
        producer.flush()
        print(f"Done. Sent {sent:,} events.")
    except KeyboardInterrupt:
        producer.flush()
        print(f"\nInterrupted. Sent {sent:,} events.")


if __name__ == "__main__":
    main()
