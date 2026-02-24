#!/usr/bin/env bash
# Run only the app stack: no Grafana, Jaeger, OpenSearch, Prometheus, or in-demo collector.
# All telemetry goes to the collector on the host at host.docker.internal:4317/4318.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
docker compose -f docker-compose.app-only.yml up -d "$@"
