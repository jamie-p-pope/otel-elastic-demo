#!/usr/bin/env bash
# Wrapper: start / stop / status for the OTLP sample app (uvicorn on port 8000).
# Optional: traffic-start / traffic-stop for background generate_traffic.py --loop.
# Run from repo root or from sample_app/.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
PID_FILE="$SCRIPT_DIR/.sample-app.pid"
TRAFFIC_PID_FILE="$SCRIPT_DIR/.sample-app-traffic.pid"
PORT=8000
OTEL_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}"
OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-otlp-sample-app}"

ensure_venv() {
  if [[ ! -d .venv ]]; then
    echo "Creating .venv..."
    python3 -m venv .venv
    .venv/bin/pip install -q -r requirements.txt
  fi
  source .venv/bin/activate
}

is_running() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
  fi
  return 1
}

cmd_start() {
  if is_running "$PID_FILE" >/dev/null; then
    echo "Sample app already running (PID $(cat "$PID_FILE")). Use stop first."
    return 1
  fi
  ensure_venv
  export OTEL_EXPORTER_OTLP_ENDPOINT="$OTEL_ENDPOINT"
  export OTEL_SERVICE_NAME="$OTEL_SERVICE_NAME"
  uvicorn app:app --host 0.0.0.0 --port "$PORT" &>/dev/null &
  echo $! > "$PID_FILE"
  echo "Sample app started (PID $(cat "$PID_FILE")), http://0.0.0.0:$PORT"
}

cmd_stop() {
  if is_running "$PID_FILE" >/dev/null; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "Sample app stopped."
  else
    echo "Sample app not running."
  fi
  # Also stop background traffic if running
  if is_running "$TRAFFIC_PID_FILE" >/dev/null; then
    kill "$(cat "$TRAFFIC_PID_FILE")" 2>/dev/null || true
    rm -f "$TRAFFIC_PID_FILE"
    echo "Background traffic generator stopped."
  fi
}

cmd_status() {
  local app_pid
  local traffic_pid
  if app_pid=$(is_running "$PID_FILE"); then
    echo "Sample app: running (PID $app_pid), http://localhost:$PORT"
  else
    echo "Sample app: stopped"
  fi
  if traffic_pid=$(is_running "$TRAFFIC_PID_FILE"); then
    echo "Traffic generator: running (PID $traffic_pid)"
  else
    echo "Traffic generator: stopped"
  fi
  if command -v ss &>/dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
      echo "Port $PORT: in use"
    else
      echo "Port $PORT: free"
    fi
  fi
}

cmd_traffic_start() {
  if ! is_running "$PID_FILE" >/dev/null; then
    echo "Start the sample app first (./sample-app.sh start)."
    return 1
  fi
  if is_running "$TRAFFIC_PID_FILE" >/dev/null; then
    echo "Traffic generator already running (PID $(cat "$TRAFFIC_PID_FILE"))."
    return 1
  fi
  ensure_venv
  BASE="${SAMPLE_APP_BASE_URL:-http://localhost:8000}"
  python3 generate_traffic.py "$BASE" --loop --interval "${SAMPLE_APP_INTERVAL:-12}" &>/dev/null &
  echo $! > "$TRAFFIC_PID_FILE"
  echo "Traffic generator started (PID $(cat "$TRAFFIC_PID_FILE")), loop every ${SAMPLE_APP_INTERVAL:-12}s."
}

cmd_traffic_stop() {
  if is_running "$TRAFFIC_PID_FILE" >/dev/null; then
    kill "$(cat "$TRAFFIC_PID_FILE")" 2>/dev/null || true
    rm -f "$TRAFFIC_PID_FILE"
    echo "Traffic generator stopped."
  else
    echo "Traffic generator not running."
  fi
}

case "${1:-}" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  status)  cmd_status ;;
  traffic-start) cmd_traffic_start ;;
  traffic-stop)  cmd_traffic_stop ;;
  *)
    echo "Usage: $0 { start | stop | status | traffic-start | traffic-stop }"
    echo "  start         Start the sample app (uvicorn on port $PORT)."
    echo "  stop          Stop the sample app (and any background traffic)."
    echo "  status        Show app and traffic process status."
    echo "  traffic-start Start background traffic generator (requires app running)."
    echo "  traffic-stop  Stop background traffic generator."
    echo ""
    echo "Env: OTEL_EXPORTER_OTLP_ENDPOINT (default http://localhost:4318), OTEL_SERVICE_NAME (default otlp-sample-app),"
    echo "     SAMPLE_APP_BASE_URL (default http://localhost:8000), SAMPLE_APP_INTERVAL (default 12)."
    exit 1
    ;;
esac
