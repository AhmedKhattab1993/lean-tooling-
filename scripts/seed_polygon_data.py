#!/usr/bin/env python3
"""Download Polygon aggregates and persist them into the shared lean-data volume.

The script currently hydrates 1-second aggregates for US equities. Extend as needed for
minute bars or raw trades/quotes.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path
from typing import Iterable

import requests

API_BASE = "https://api.polygon.io"


def daterange(start: dt.date, end: dt.date) -> Iterable[dt.date]:
    current = start
    while current <= end:
        yield current
        current += dt.timedelta(days=1)


def fetch_second_aggregates(symbol: str, session: requests.Session, target_date: dt.date, api_key: str) -> list[dict]:
    start = dt.datetime.combine(target_date, dt.time.min).isoformat() + "Z"
    end = dt.datetime.combine(target_date, dt.time.max).isoformat() + "Z"
    url = f"{API_BASE}/v2/aggs/ticker/{symbol}/range/1/second/{start}/{end}"
    params = {"limit": 50000, "apiKey": api_key, "adjusted": "true"}

    results: list[dict] = []
    while True:
        response = session.get(url, params=params, timeout=30)
        response.raise_for_status()
        payload = response.json()
        results.extend(payload.get("results", []))
        next_url = payload.get("next_url")
        if not next_url:
            break
        url = next_url
        params = {"apiKey": api_key}
    return results


def write_payload(base_dir: Path, symbol: str, day: dt.date, data: list[dict]) -> Path:
    target_dir = base_dir / "equity" / "usa" / "polygon" / symbol.lower()
    target_dir.mkdir(parents=True, exist_ok=True)
    target_file = target_dir / f"{day.strftime('%Y%m%d')}_second.json"
    with target_file.open("w", encoding="utf-8") as fh:
        json.dump({"symbol": symbol.upper(), "day": day.isoformat(), "results": data}, fh)
    return target_file


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed Polygon second aggregate data into lean-data volume")
    parser.add_argument("symbol", help="Ticker symbol, e.g. TSLA")
    parser.add_argument("start", help="Start date (YYYY-MM-DD)")
    parser.add_argument("end", help="End date (YYYY-MM-DD)")
    parser.add_argument(
        "--output",
        default=os.environ.get("LEAN_DATA", "lean-data"),
        help="Destination data folder (defaults to LEAN_DATA env or ./lean-data)",
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("POLYGON_API_KEY"),
        help="Polygon API key (defaults to POLYGON_API_KEY env)",
    )
    args = parser.parse_args()

    if not args.api_key:
        parser.error("Polygon API key is required (set POLYGON_API_KEY or pass --api-key)")

    try:
        start_date = dt.date.fromisoformat(args.start)
        end_date = dt.date.fromisoformat(args.end)
    except ValueError as exc:
        parser.error(f"Invalid date: {exc}")

    if end_date < start_date:
        parser.error("End date must be on or after start date")

    target_root = Path(args.output).resolve()
    session = requests.Session()

    for day in daterange(start_date, end_date):
        print(f"Fetching {args.symbol} second aggregates for {day}")
        aggregates = fetch_second_aggregates(args.symbol.upper(), session, day, args.api_key)
        output_path = write_payload(target_root, args.symbol.upper(), day, aggregates)
        print(f"  wrote {len(aggregates)} buckets -> {output_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
