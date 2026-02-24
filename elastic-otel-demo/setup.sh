#!/usr/bin/env bash
# setup.sh — Clone, configure, and start the Elastic OTel demo
#
# Run from: elastic-otel-demo/
# Usage:    ./setup.sh [--side-by-side]
#
# --side-by-side  Use ports 8180/8189 so it can run alongside the
#                 vanilla OTel demo (astrology-app) on 8080/8089.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE_DIR="$SCRIPT_DIR/opentelemetry-demo"
TEMPLATE="$SCRIPT_DIR/.env.override.template"
SIDE_BY_SIDE=false

# Parse args
for arg in "$@"; do
  case $arg in
    --side-by-side) SIDE_BY_SIDE=true ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

echo ""
echo "=== Elastic OTel Demo Setup ==="
echo ""

# ── Step 1: Clone ────────────────────────────────────────────────────────────
if [ -d "$CLONE_DIR" ]; then
  echo "✓ opentelemetry-demo already cloned — pulling latest..."
  git -C "$CLONE_DIR" pull --ff-only || echo "  (pull failed or already up to date)"
else
  echo "→ Cloning elastic/opentelemetry-demo..."
  git clone https://github.com/elastic/opentelemetry-demo.git "$CLONE_DIR"
fi

# ── Step 2: .env.override ────────────────────────────────────────────────────
ENV_OVERRIDE="$CLONE_DIR/.env.override"

if [ ! -f "$ENV_OVERRIDE" ]; then
  echo ""
  echo "→ No .env.override found. Creating from template..."
  cp "$TEMPLATE" "$ENV_OVERRIDE"
  echo ""
  echo "  You need to fill in your Elastic credentials."
  echo "  Edit: $ENV_OVERRIDE"
  echo ""
  echo "  For Elastic Cloud (hosted):"
  echo "    ELASTIC_APM_SERVER_ENDPOINT=https://<apm-server>.elastic.cloud:443"
  echo "    ELASTIC_APM_SECRET_TOKEN=<your-token>"
  echo ""
  echo "  For Elastic Cloud Serverless:"
  echo "    ELASTIC_OTLP_ENDPOINT=https://<project>.ingest.<region>.aws.elastic.cloud"
  echo "    ELASTIC_API_KEY=<your-api-key>"
  echo ""
  read -p "  Open .env.override in \$EDITOR now? [Y/n] " open_editor
  if [[ "$open_editor" != "n" && "$open_editor" != "N" ]]; then
    "${EDITOR:-vi}" "$ENV_OVERRIDE"
  fi
else
  echo "✓ .env.override already exists — using existing credentials"
fi

# ── Step 3: Side-by-side port offsets ────────────────────────────────────────
if [ "$SIDE_BY_SIDE" = true ]; then
  echo ""
  echo "→ --side-by-side: setting ports 8180/8189 in .env.override..."
  # Add port overrides if not already present
  if ! grep -q "^ENVOY_PORT=" "$ENV_OVERRIDE"; then
    echo "" >> "$ENV_OVERRIDE"
    echo "# Side-by-side port offsets (added by setup.sh --side-by-side)" >> "$ENV_OVERRIDE"
    echo "ENVOY_PORT=8180" >> "$ENV_OVERRIDE"
    echo "LOCUST_WEB_PORT=8189" >> "$ENV_OVERRIDE"
  fi
  echo "  Frontend:  http://localhost:8180"
  echo "  Locust:    http://localhost:8189"
else
  echo ""
  echo "  Frontend:  http://localhost:8080"
  echo "  Locust:    http://localhost:8089"
fi

# ── Step 4: Start ────────────────────────────────────────────────────────────
echo ""
echo "→ Starting the Elastic OTel demo..."
echo ""
cd "$CLONE_DIR"
make start

echo ""
echo "=== Elastic OTel demo is running ==="
echo ""
echo "To stop:   cd $CLONE_DIR && make stop"
echo "Logs:      cd $CLONE_DIR && docker compose logs -f"
