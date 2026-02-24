#!/usr/bin/env bash
# start-elastic.sh — Start the Elastic OTel demo (EDOT agents)
#
# Usage:
#   ./start-elastic.sh                    # start on default ports 8080/8089
#   ./start-elastic.sh --side-by-side     # start on ports 8180/8189 (alongside vanilla demo)
#   ./start-elastic.sh --stop             # stop the Elastic demo
#
# Requires: elastic-otel-demo/opentelemetry-demo to be cloned.
# Run elastic-otel-demo/setup.sh first if you haven't already.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$SCRIPT_DIR/elastic-otel-demo/opentelemetry-demo"
SIDE_BY_SIDE=false
STOP=false

for arg in "$@"; do
  case $arg in
    --side-by-side) SIDE_BY_SIDE=true ;;
    --stop) STOP=true ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── STOP ─────────────────────────────────────────────────────────────────────
if [ "$STOP" = true ]; then
  if [ ! -d "$DEMO_DIR" ]; then
    echo "Nothing to stop — $DEMO_DIR not found"
    exit 0
  fi
  echo "=== Stopping Elastic OTel demo ==="
  cd "$DEMO_DIR"
  make stop 2>/dev/null || docker compose down 2>/dev/null || true
  echo "=== Stopped ==="
  exit 0
fi

# ── PRE-CHECKS ────────────────────────────────────────────────────────────────
if [ ! -d "$DEMO_DIR" ]; then
  echo "ERROR: Elastic demo not cloned yet."
  echo ""
  echo "Run setup first:"
  echo "  cd elastic-otel-demo && ./setup.sh"
  echo ""
  echo "Or with side-by-side ports:"
  echo "  cd elastic-otel-demo && ./setup.sh --side-by-side"
  echo ""
  exit 1
fi

if [ ! -f "$DEMO_DIR/.env.override" ]; then
  echo "ERROR: .env.override not found in $DEMO_DIR"
  echo ""
  echo "Copy and fill in your Elastic credentials:"
  echo "  cp elastic-otel-demo/.env.override.template $DEMO_DIR/.env.override"
  echo "  \$EDITOR $DEMO_DIR/.env.override"
  echo ""
  exit 1
fi

# ── START ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== Starting Elastic OTel Demo (EDOT) ==="
echo ""

# Apply side-by-side port offsets if requested
if [ "$SIDE_BY_SIDE" = true ]; then
  if ! grep -q "^ENVOY_PORT=" "$DEMO_DIR/.env.override"; then
    echo "→ Adding side-by-side port offsets to .env.override..."
    echo "" >> "$DEMO_DIR/.env.override"
    echo "# Side-by-side ports" >> "$DEMO_DIR/.env.override"
    echo "ENVOY_PORT=8180" >> "$DEMO_DIR/.env.override"
    echo "LOCUST_WEB_PORT=8189" >> "$DEMO_DIR/.env.override"
  fi
  FRONTEND_PORT=8180
  LOCUST_PORT=8189
else
  FRONTEND_PORT=8080
  LOCUST_PORT=8089
fi

cd "$DEMO_DIR"
make start

echo ""
echo "=== Elastic OTel demo is running ==="
echo ""
echo "  Frontend:       http://localhost:${FRONTEND_PORT}"
echo "  Load generator: http://localhost:${LOCUST_PORT}"
echo ""
echo "  Logs: cd $DEMO_DIR && docker compose logs -f"
echo ""
echo "To stop: ./start-elastic.sh --stop"
