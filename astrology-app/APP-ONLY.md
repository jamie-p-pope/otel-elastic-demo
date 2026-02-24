# App-only stack (your collector, no Grafana/Jaeger/OpenSearch)

This compose file runs **only the demo app services** plus the infra they need (Postgres, Valkey, Kafka, Flagd, LLM). No Grafana, Jaeger, OpenSearch, Prometheus, or in-demo collector. All telemetry is sent to **your** collector at `host.docker.internal:4317` (gRPC) and `4318` (HTTP).

## What runs

- **Infra:** postgresql, valkey-cart, kafka, flagd, flagd-ui, llm  
- **App:** accounting, ad, cart, checkout, currency, email, fraud-detection, frontend, image-provider, load-generator, payment, product-catalog, product-reviews, quote, recommendation, shipping, frontend-proxy  

**LLM** is used only by **product-reviews** for AI-generated review summaries (the “astronomy” demo). If it OOMs (exit 137) on a small instance, give it more memory or ignore it; the rest of the app still runs. Kafka has a 90s healthcheck start period so it can become healthy before dependents (checkout, accounting, fraud-detection) give up.  

## Requirements

- Run from the **official opentelemetry-demo repo** directory (so `.env` is present for `IMAGE_NAME`, `DEMO_VERSION`, ports, etc.).
- Your collector must be listening on the **host** on **4317** (gRPC) and **4318** (HTTP). On Linux, `host.docker.internal` is provided via `extra_hosts` in the compose.

## Run

```bash
./run-app-only.sh
```

Or:

```bash
docker compose -f docker-compose.app-only.yml up -d
```

## Access

- **Frontend:** `http://<host>:8080` (Envoy proxy in front of the app)
- **Load generator (Locust):** `http://<host>:8089`

**Load generator (Locust):** It runs inside the `load-generator` container and sends HTTP traffic to the frontend via `frontend-proxy`. In Elastic you’ll see that traffic as **frontend-proxy** (and downstream as frontend, checkout, cart, etc.). To change load:
- Open `http://<host>:8089`, then set **Number of users** and **Spawn rate**, click **Start swarming**.
- Or set env before starting: `LOCUST_USERS=20` and `LOCUST_AUTOSTART=true` in `.env` (then restart the stack).

Traces, metrics, and logs from all services go to your host collector (e.g. into Elastic).

## Stop / remove

```bash
docker compose -f docker-compose.app-only.yml down
docker compose -f docker-compose.app-only.yml down --rmi all   # remove images too
```
