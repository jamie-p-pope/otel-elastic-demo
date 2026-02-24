# OpenTelemetry → Elastic Observability: Demo Repository

This repo demonstrates two approaches to sending OpenTelemetry signals (traces, metrics, logs) to **Elastic Observability** from a realistic microservices application — without replacing your existing OTel infrastructure with Elastic's agents.

> **The core scenario:** Customers who already have OpenTelemetry deployed don't want to swap out their collectors. This repo shows that path works cleanly, and also shows the fully-Elastic path side by side.

---

## What's in This Repo

| Directory | What it is |
|-----------|-----------|
| `astrology-app/` | Vanilla OTel demo (17-service microservices app) running **app-only** — no built-in observability stack; telemetry goes to **your** collector |
| `sample_app/` | Minimal Python orders API, manually instrumented with OTel SDK. Good for quick trace/log validation |
| `elastic-otel-demo/` | Instructions + config for the **Elastic fork** of the OTel demo, instrumented with EDOT agents, sends directly to Elastic |

---

## Architecture

### Path 1 — Vanilla OTel Collector → Elastic

```
┌────────────────────────────────────────────────────────────────┐
│                      Host (EC2 or local)                       │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │               Docker: astrology-app stack               │  │
│  │  (17 services: frontend, checkout, cart, product-       │  │
│  │   catalog, recommendation, payment, shipping, etc.)     │  │
│  │  All services → OTLP → host.docker.internal:4317/4318  │  │
│  └────────────────────────┬────────────────────────────────┘  │
│                           │ OTLP gRPC/HTTP                    │
│  ┌────────────────────────▼────────────────────────────────┐  │
│  │         OTel Collector (otelcol-contrib)                │  │
│  │         Listening: 0.0.0.0:4317 (gRPC), :4318 (HTTP)   │  │
│  │         Exporter: OTLP → Elastic APM / Serverless       │  │
│  └────────────────────────┬────────────────────────────────┘  │
│                           │                                   │
│  ┌────────────────────────┼────────────────────────────────┐  │
│  │     sample_app         │                                │  │
│  │     (port 8000)        │                                │  │
│  │     → localhost:4318 ──┘                                │  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────┬────────────────────────────────┘
                                │ OTLP/HTTPS
                   ┌────────────▼──────────────┐
                   │      Elastic Cloud         │
                   │  APM / Observability       │
                   └────────────────────────────┘
```

### Path 2 — Elastic OTel Demo (EDOT agents, direct to Elastic)

```
┌────────────────────────────────────────────────────────────────┐
│                      Host (EC2 or local)                       │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │            Docker: elastic-otel-demo stack              │  │
│  │  Same microservices but instrumented with EDOT agents   │  │
│  │  (Elastic Distribution of OpenTelemetry)                │  │
│  │  Java / .NET / Node.js / Python: EDOT agents            │  │
│  │  Collector: Elastic OTel Collector distribution         │  │
│  └────────────────────────┬────────────────────────────────┘  │
└───────────────────────────┬────────────────────────────────────┘
                            │ OTLP/HTTPS (or Elasticsearch exporter)
               ┌────────────▼──────────────┐
               │      Elastic Cloud         │
               │  APM / Observability       │
               └────────────────────────────┘
```

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Docker + Docker Compose v2 | `docker compose version` — must be v2 (`docker compose`, not `docker-compose`) |
| Python 3.9+ | For `sample_app` only |
| 8 GB RAM minimum | The full microservices stack is memory-heavy; 16 GB recommended |
| Elastic credentials | OTLP endpoint URL + API key (or Serverless token) |
| AWS CLI (optional) | Only needed for EC2 security group management |

---

## Part 1: Vanilla OTel → Elastic

### Step 1: Configure and run the OTel Collector

The collector bridges your services to Elastic. It needs a config file (`config.yml`) that sets:
- **Receiver:** OTLP (gRPC port 4317, HTTP port 4318)
- **Exporter:** OTLP to your Elastic endpoint

Minimal `config.yml`:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:

exporters:
  otlphttp/elastic:
    endpoint: "${ELASTIC_OTLP_ENDPOINT}"
    headers:
      Authorization: "ApiKey ${ELASTIC_API_KEY}"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlphttp/elastic]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlphttp/elastic]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlphttp/elastic]
```

Set the environment variables before running the collector:

```bash
export ELASTIC_OTLP_ENDPOINT=https://<your-project>.ingest.us-east-1.aws.elastic.cloud
export ELASTIC_API_KEY=<your-api-key>
```

The OTLP ingest endpoint and API key work for both **Elastic Cloud Hosted** and **Serverless**. Get your endpoint and API key from Kibana → Stack Management → API Keys.

**Run the collector (Docker):**

```bash
docker run -d \
  --name otel-collector \
  -v $(pwd)/config.yml:/etc/otelcol-contrib/config.yaml \
  -p 4317:4317 \
  -p 4318:4318 \
  otel/opentelemetry-collector-contrib:latest \
  --config=/etc/otelcol-contrib/config.yaml
```

**Or as a binary:**

```bash
# Download from: https://github.com/open-telemetry/opentelemetry-collector-releases/releases
./otelcol-contrib --config=config.yml
```

Confirm it's listening:

```bash
# Should show 0.0.0.0:4317 and 0.0.0.0:4318
ss -tlnp | grep -E '4317|4318'
# or on macOS:
lsof -i :4317 -i :4318
```

---

### Step 2: Run the Vanilla OTel Demo (astrology-app)

This is the [OpenTelemetry Demo](https://github.com/open-telemetry/opentelemetry-demo) — a 17-service e-commerce microservices app. It uses the same architecture as Google's Online Boutique / microservices demo, instrumented with vanilla OTel agents across Go, Java, .NET, Node.js, Python, PHP, and C#.

The `docker-compose.app-only.yml` strips out all built-in observability (no Grafana, Jaeger, Prometheus) and sends all telemetry to your external collector.

```bash
cd astrology-app
./run-app-only.sh
```

Or manually:

```bash
cd astrology-app
docker compose -f docker-compose.app-only.yml up -d
```

**Access:**

| UI | URL |
|----|-----|
| Frontend (shop) | `http://<host>:8080` |
| Load generator (Locust) | `http://<host>:8089` |

Locust starts automatically and drives realistic e-commerce traffic. Within a minute you should see traces in Elastic under **APM → Services** with service names like `frontend`, `checkout`, `cart`, `product-catalog`, etc.

**Stop:**

```bash
cd astrology-app
docker compose -f docker-compose.app-only.yml down
```

---

### Step 3: Run the Sample App (optional)

A minimal FastAPI orders API — useful for quick trace/log validation without spinning up the full stack.

```bash
cd sample_app
./sample-app.sh start           # starts API on port 8000
./sample-app.sh traffic-start  # optional: background traffic loop
./sample-app.sh status
./sample-app.sh stop
```

**Environment (optional overrides):**

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318   # default
export OTEL_SERVICE_NAME=otlp-sample-app                   # default
```

In Elastic: Traces → service `otlp-sample-app`; Logs → `service.name: otlp-sample-app`.

---

## Part 2: Elastic OTel Demo (EDOT)

The [Elastic fork](https://github.com/elastic/opentelemetry-demo) of the OTel demo replaces vanilla agents with **EDOT** (Elastic Distribution of OpenTelemetry) across Java, .NET, Node.js, and Python services. The collector is also swapped for Elastic's distribution.

**Key difference:** EDOT adds Elastic-specific enrichments on top of standard OTel, providing tighter integration with Elastic's UI features.

See [`elastic-otel-demo/README.md`](elastic-otel-demo/README.md) for full setup.

**Quick path:**

```bash
cd elastic-otel-demo
./setup.sh          # clones the repo, copies your .env.override, and runs demo.sh
```

Or manually:

```bash
git clone https://github.com/elastic/opentelemetry-demo.git
cd opentelemetry-demo
cp ../elastic-otel-demo/.env.override.template .env.override
# Edit .env.override with your Elastic endpoint + API key
make start
```

---

## Running Both Simultaneously

The vanilla demo uses ports **8080** and **8089**. To run both stacks at the same time, run the Elastic demo on different ports by setting these in its `.env.override`:

```bash
# elastic-otel-demo/.env.override — port offsets for side-by-side
ENVOY_PORT=8180
LOCUST_WEB_PORT=8189
```

| Stack | Frontend | Load Generator |
|-------|----------|----------------|
| Vanilla OTel demo | `http://<host>:8080` | `http://<host>:8089` |
| Elastic OTel demo | `http://<host>:8180` | `http://<host>:8189` |
| Sample app | `http://<host>:8000` | — |

Both will send telemetry to Elastic. You can compare service maps, trace quality, and attribute richness between the two instrumentation approaches.

---

## EC2 / AWS Deployment

### Ports to open

The following ports need inbound access in your EC2 security group:

| Port | Service | Required? |
|------|---------|-----------|
| 8080 | Vanilla demo frontend | Yes |
| 8089 | Vanilla demo Locust | Yes |
| 8180 | Elastic demo frontend (if running both) | Optional |
| 8189 | Elastic demo Locust (if running both) | Optional |
| 8000 | Sample app | Optional |
| 4317 | OTel Collector gRPC | Only if sending from external hosts |
| 4318 | OTel Collector HTTP | Only if sending from external hosts |

### Open ports via AWS CLI

```bash
# Find your instance security group
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,SecurityGroups[0].GroupId]' \
  --output table

# Open required ports (replace sg-xxxxxxxx)
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxx \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxx \
  --protocol tcp --port 8089 --cidr 0.0.0.0/0
```

See [`astrology-app/EC2-SECURITY-GROUPS.md`](astrology-app/EC2-SECURITY-GROUPS.md) for the full AWS CLI reference.

### Confirm services are reachable

```bash
# On the EC2 host — confirm Docker published ports to 0.0.0.0
sudo ss -tlnp | grep -E '8080|8089|8000|4317|4318'
```

---

## Quick Reference

### Start everything (vanilla path)

```bash
# 1. Start collector (Docker)
docker run -d --name otel-collector \
  -v $(pwd)/config.yml:/etc/otelcol-contrib/config.yaml \
  -p 4317:4317 -p 4318:4318 \
  otel/opentelemetry-collector-contrib:latest \
  --config=/etc/otelcol-contrib/config.yaml

# 2. Start demo
cd astrology-app && ./run-app-only.sh

# 3. (Optional) Start sample app
cd ../sample_app && ./sample-app.sh start && ./sample-app.sh traffic-start
```

### Stop everything

```bash
cd astrology-app && docker compose -f docker-compose.app-only.yml down
cd ../sample_app && ./sample-app.sh stop
docker stop otel-collector && docker rm otel-collector
```

---

## Troubleshooting

**Services start but no data in Elastic**
- Check the collector is running and listening: `lsof -i :4317 -i :4318` (macOS) or `ss -tlnp | grep -E '4317|4318'` (Linux)
- Check collector logs: `docker logs otel-collector`
- Verify your Elastic endpoint and API key in `config.yml`
- For the demo app on EC2 (Linux), `host.docker.internal` is added via `extra_hosts` in the compose file — confirm it resolves: `docker exec frontend-proxy ping -c1 host.docker.internal`

**Frontend unreachable from browser**
- Confirm ports are open in your EC2 security group (see above)
- Confirm Docker published to `0.0.0.0` (not `127.0.0.1`): `sudo ss -tlnp | grep 8080`

**LLM service OOMKilled (exit 137)**
- The `llm` container (used by `product-reviews` for AI review summaries) can OOM on smaller instances
- Either give your EC2 instance more RAM, or remove the `product-reviews` service — the rest of the demo runs fine without it

**Kafka takes too long to be healthy**
- Kafka has a 90-second startup grace period built into the healthcheck
- If dependent services (checkout, accounting, fraud-detection) fail on first start, wait 2 minutes and run `docker compose -f docker-compose.app-only.yml up -d` again

**`docker compose` command not found**
- Ensure you're using Docker Compose v2: `docker compose version` (space, not hyphen)
- Docker Desktop includes v2; on Linux: `sudo apt install docker-compose-plugin`

---

## Repo Structure

```
OpenTelemetry-Apps-Master/
├── README.md                         ← You are here
├── config.yml                        ← OTel Collector config (create from template above)
├── astrology-app/                    ← Vanilla OTel demo (app-only stack)
│   ├── docker-compose.app-only.yml   ← 17-service compose, no observability stack
│   ├── .env                          ← Image versions, service ports
│   ├── run-app-only.sh               ← Start wrapper
│   ├── APP-ONLY.md                   ← Stack-specific notes
│   └── EC2-SECURITY-GROUPS.md        ← AWS CLI commands for security groups
├── sample_app/                       ← Minimal orders API
│   ├── app.py                        ← FastAPI + OTel SDK
│   ├── generate_traffic.py           ← Traffic generator
│   ├── requirements.txt
│   ├── sample-app.sh                 ← Start/stop/status wrapper
│   └── README.md
└── elastic-otel-demo/                ← Elastic OTel demo setup
    ├── README.md                     ← Full guide for the Elastic demo
    ├── setup.sh                      ← Clone + configure + run helper
    └── .env.override.template        ← Elastic credentials template
```
