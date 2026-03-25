#!/usr/bin/env python3
"""Flush stale batch/result/task keys from Redis."""
import redis
import os

REDIS_URL = os.environ.get("REDIS_URL")
if not REDIS_URL:
    raise SystemExit("REDIS_URL is required")
r = redis.from_url(REDIS_URL)

patterns = [
    "batch:*",
    "batch_results:*",
    "pending_batch:*",
    "result:*",
    "verified_result:*",
    "task:*",
]
total = 0
for p in patterns:
    keys = list(r.scan_iter(p))
    if keys:
        r.delete(*keys)
        total += len(keys)
        print(f"Deleted {len(keys)} keys matching {p}")
    else:
        print(f"No keys matching {p}")
print(f"Total deleted: {total}")
