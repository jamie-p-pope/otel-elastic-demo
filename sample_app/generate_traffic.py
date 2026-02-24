#!/usr/bin/env python3
"""
Generate traffic against the orders API for OTLP/Elastic testing.
Uses stdlib only (no extra deps). Run while the app is up on port 8000.

Examples:
  python3 generate_traffic.py                    # one cycle
  python3 generate_traffic.py --count 5          # 5 cycles, 12s apart
  python3 generate_traffic.py --loop             # run until Ctrl+C
  python3 generate_traffic.py --loop --interval 20
"""
import argparse
import json
import random
import signal
import sys
import time
import urllib.error
import urllib.request

ITEMS = ("widget", "gadget", "sprocket", "gizmo", "thingamajig", "doohickey")

BASE = "http://localhost:8000"
DEFAULT_INTERVAL = 12  # seconds between cycles (gentle for demos)


def request(base: str, method: str, path: str, body: dict | None = None) -> dict | list:
    url = f"{base.rstrip('/')}{path}"
    req = urllib.request.Request(url, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
        req.data = json.dumps(body).encode()
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            json.loads(e.read().decode())
        except Exception:
            pass
        return {}
    except urllib.error.URLError as e:
        print(f"Error: {e.reason}", file=sys.stderr)
        raise


def run_one_cycle(base: str, verbose: bool) -> bool:
    """Run one traffic cycle with varied operations. Returns True on success."""
    try:
        ids = []
        # Variable number of creates (1–3) with random items and quantities
        num_creates = random.randint(1, 3)
        for _ in range(num_creates):
            item = random.choice(ITEMS)
            qty = random.randint(1, 5)
            r = request(base, "POST", "/orders", {"item": item, "quantity": qty})
            oid = r.get("id", "")
            if oid:
                ids.append(oid)

        # List orders (1–2 times per cycle so it shows in Transactions)
        for _ in range(random.randint(1, 2)):
            list_resp = request(base, "GET", "/orders")
        order_list = list_resp.get("orders", []) if isinstance(list_resp, dict) else []

        # Get existing orders (2–3 times per cycle so get_order shows)
        if ids:
            for _ in range(random.randint(2, 3)):
                oid = random.choice(ids)
                request(base, "GET", f"/orders/{oid}")

        # 404 (always) – produces a warning log
        request(base, "GET", "/orders/bad-id")

        # Complete one random order (if we have any)
        if ids:
            oid = random.choice(ids)
            request(base, "POST", f"/orders/{oid}/complete")

        if verbose:
            print(f"  → created {num_creates} orders; list; get(s); 404; complete")
        return True
    except urllib.error.URLError:
        return False


def main() -> None:
    global BASE
    parser = argparse.ArgumentParser(
        description="Generate traffic to the orders API for OTLP/Elastic demos.",
        epilog="Use --loop to run until Ctrl+C; --interval sets seconds between cycles.",
    )
    parser.add_argument(
        "base_url",
        nargs="?",
        default=BASE,
        help=f"Base URL of the API (default: {BASE})",
    )
    parser.add_argument(
        "-n", "--count",
        type=int,
        default=1,
        metavar="N",
        help="Number of cycles to run (default: 1)",
    )
    parser.add_argument(
        "-l", "--loop",
        action="store_true",
        help="Run indefinitely until Ctrl+C",
    )
    parser.add_argument(
        "-i", "--interval",
        type=float,
        default=DEFAULT_INTERVAL,
        metavar="SEC",
        help=f"Seconds between cycles (default: {DEFAULT_INTERVAL})",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Print a line per cycle; default when count=1",
    )
    args = parser.parse_args()
    base = args.base_url.rstrip("/")
    verbose = args.verbose or (args.count == 1 and not args.loop)

    if args.loop:
        args.count = None  # sentinel for "infinite"
    if args.count is not None and args.count < 1:
        parser.error("--count must be >= 1 (or use --loop)")

    running = True

    def stop(_, __):
        nonlocal running
        running = False
        print("\nStopping after current cycle...", file=sys.stderr)

    signal.signal(signal.SIGINT, stop)
    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, stop)

    print(f"Generating traffic → {base}", end="")
    if args.loop:
        print(f" (loop every {args.interval}s, Ctrl+C to stop)")
    elif args.count and args.count > 1:
        print(f" ({args.count} cycles, {args.interval}s apart)")
    else:
        print()
    print()

    cycle = 0
    while running:
        cycle += 1
        if verbose or (args.count is None or args.count > 1):
            prefix = f"[{cycle}] " if (args.loop or (args.count and args.count > 1)) else ""
            print(f"{prefix}Cycle {cycle}...", end=" " if not verbose else "\n")
        ok = run_one_cycle(base, verbose)
        if not ok:
            print("Failed.", file=sys.stderr)
            sys.exit(1)
        if verbose and cycle > 1:
            print(f"  → cycle {cycle} ok")
        elif not verbose and (args.loop or (args.count and args.count > 1)):
            print("ok")

        if args.count is not None and cycle >= args.count:
            break
        if running and (args.loop or (args.count and cycle < args.count)):
            time.sleep(args.interval)

    print()
    print("Done. Check Elastic: Traces (service: otlp-sample-app), Logs (service.name: otlp-sample-app).")


if __name__ == "__main__":
    main()
