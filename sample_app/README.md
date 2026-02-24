# OTLP Sample App

Small **orders** API: create/list/get/complete orders (in-memory). Built to produce clear **traces** (nested spans) and **logs** (info/warning) so you can see them in Elastic. No collector config changes—your existing OTLP pipelines handle it.

## Quick start (same host as collector)

**Option A – wrapper (start/stop/status):**
```bash
./sample-app.sh start          # starts app on port 8000 (creates .venv if needed)
./sample-app.sh traffic-start  # optional: background traffic loop
./sample-app.sh status
./sample-app.sh stop           # stops app and traffic
```

**Option B – manual:**
1. **Setup:** `cd sample_app && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`
2. **Run app:** `export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 OTEL_SERVICE_NAME=otlp-sample-app && uvicorn app:app --host 0.0.0.0 --port 8000`
3. **Generate traffic** (in another terminal): `cd sample_app && source .venv/bin/activate && python3 generate_traffic.py`
4. **In Elastic:** Traces → service `otlp-sample-app`; Logs → filter `service.name: otlp-sample-app`.

See **Generate traffic** below for loop/demo options.

## Endpoints

| Method | Path | What it does |
|--------|------|--------------|
| POST | `/orders` | Create order (body: `{"item": "widget", "quantity": 2}`). Spans: `create_order` → `validate_order` → `persist_order`. |
| GET | `/orders` | List orders (query: `?limit=10`). Span: `list_orders`. |
| GET | `/orders/{id}` | Get one order. Span: `get_order`. 404 logs a warning. |
| POST | `/orders/{id}/complete` | Mark order completed. Span: `complete_order`. |

## Setup

```bash
cd sample_app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run (same host as collector)

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export OTEL_SERVICE_NAME=otlp-sample-app
uvicorn app:app --host 0.0.0.0 --port 8000
```

## Generate traffic

After the app is running, use the script below (or curl) to hit the API so traces and logs show up in Elastic.

**Script (recommended):**

```bash
python3 generate_traffic.py
# Or against another host:
python3 generate_traffic.py http://your-host:8000

# Run 10 cycles, 12 seconds apart (demo-friendly):
python3 generate_traffic.py --count 10

# Run until Ctrl+C (e.g. during a demo), one cycle every 15s:
python3 generate_traffic.py --loop --interval 15
```

Each cycle varies: 1–3 creates (random item and quantity), list, 1–2 gets, a 404 (warning log), and one complete—so traces and logs show a mix of operations. Use `--count N` for N cycles or `--loop` to run continuously; `--interval SEC` (default 12) sets the delay between cycles so you don’t trip rate limits.

**Manual curl:**

```bash
# Create a couple of orders
curl -s -X POST http://localhost:8000/orders -H "Content-Type: application/json" -d '{"item":"widget","quantity":2}'
curl -s -X POST http://localhost:8000/orders -H "Content-Type: application/json" -d '{"item":"gadget","quantity":1}'

# List and get (use an id from create response)
curl -s http://localhost:8000/orders
curl -s http://localhost:8000/orders/<order_id>
curl -s -X POST http://localhost:8000/orders/<order_id>/complete

# Trigger a warning (404)
curl -s http://localhost:8000/orders/bad-id
```

## In Elastic

- **Traces:** Service `otlp-sample-app`, spans like `create_order`, `validate_order`, `persist_order`, `get_order`, `complete_order`.
- **Logs:** Filter `service.name: otlp-sample-app`; you’ll see "Order validated", "Order persisted", "Order not found", etc.
