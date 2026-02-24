#!/usr/bin/env bash
# start-vanilla.sh — Start the vanilla OTel collector + demo stack
#
# Usage:
#   ./start-vanilla.sh              # collector (Docker) + astrology-app demo
#   ./start-vanilla.sh --with-sample-app  # also start the sample_app
#   ./start-vanilla.sh --stop       # stop everything
#
# Requires: config.yml in the same directory as this script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yml"
WITH_SAMPLE_APP=false
STOP=false

for arg in "$@"; do
  case $arg in
    --with-sample-app) WITH_SAMPLE_APP=true ;;
    --stop) STOP=true ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── STOP ─────────────────────────────────────────────────────────────────────
if [ "$STOP" = true ]; then
  echo "=== Stopping vanilla OTel stack ==="
  echo ""
  echo "→ Stopping astrology-app..."
  docker compose -f "$SCRIPT_DIR/astrology-app/docker-compose.app-only.yml" down 2>/dev/null || true

  echo "→ Stopping sample_app..."
  "$SCRIPT_DIR/sample_app/sample-app.sh" stop 2>/dev/null || true

  echo "→ Stopping OTel Collector..."
  docker stop otel-collector 2>/dev/null && docker rm otel-collector 2>/dev/null || true

  echo ""
  echo "=== All stopped ==="
  exit 0
fi

# ── START ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== Starting Vanilla OTel → Elastic Stack ==="
echo ""

# Check config.yml
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: config.yml not found at $CONFIG_FILE"
  echo ""
  echo "Create a config.yml with your Elastic endpoint. Example:"
  echo ""
  echo "  receivers:"
  echo "    otlp:"
  echo "      protocols:"
  echo "        grpc:"
  echo "          endpoint: 0.0.0.0:4317"
  echo "        http:"
  echo "          endpoint: 0.0.0.0:4318"
  echo "  processors:"
  echo "    batch:"
  echo "  exporters:"
  echo "    otlp/elastic:"
  echo "      endpoint: \"https://<your-apm-server>.elastic.cloud:443\""
  echo "      headers:"
  echo "        Authorization: \"Bearer <your-secret-token>\""
  echo "  service:"
  echo "    pipelines:"
  echo "      traces:"
  echo "        receivers: [otlp]"
  echo "        processors: [batch]"
  echo "        exporters: [otlp/elastic]"
  echo "      metrics:"
  echo "        receivers: [otlp]"
  echo "        processors: [batch]"
  echo "        exporters: [otlp/elastic]"
  echo "      logs:"
  echo "        receivers: [otlp]"
  echo "        processors: [batch]"
  echo "        exporters: [otlp/elastic]"
  echo ""
  exit 1
fi

# Step 1: Collector
if docker ps --format '{{.Names}}' | grep -q '^otel-collector$'; then
  echo "✓ OTel Collector already running"
else
  echo "→ Starting OTel Collector..."
  docker run -d \
    --name otel-collector \
    -v "$CONFIG_FILE:/etc/otelcol-contrib/config.yaml" \
    -p 4317:4317 \
    -p 4318:4318 \
    otel/opentelemetry-collector-contrib:latest \
    --config=/etc/otelcol-contrib/config.yaml
  echo "✓ Collector started (ports 4317, 4318)"
fi

# Step 2: Astrology demo
echo "→ Starting astrology-app (vanilla OTel demo)..."
docker compose -f "$SCRIPT_DIR/astrology-app/docker-compose.app-only.yml" up -d
echo "✓ Demo started"

# Step 3: Sample app (optional)
if [ "$WITH_SAMPLE_APP" = true ]; then
  echo "→ Starting sample_app..."
  "$SCRIPT_DIR/sample_app/sample-app.sh" start
  "$SCRIPT_DIR/sample_app/sample-app.sh" traffic-start
  echo "✓ Sample app started (port 8000)"
fi

echo ""
echo "=== Vanilla OTel stack is running ==="
echo ""
echo "  Frontend:       http://localhost:8080"
echo "  Load generator: http://localhost:8089"
if [ "$WITH_SAMPLE_APP" = true ]; then
echo "  Sample app:     http://localhost:8000"
fi
echo ""
echo "  Collector logs: docker logs otel-collector -f"
echo "  Demo logs:      docker compose -f astrology-app/docker-compose.app-only.yml logs -f"
echo ""
echo "To stop: ./start-vanilla.sh --stop"
