# Elastic OTel Demo

This directory contains setup files for the **Elastic fork** of the OpenTelemetry demo. It complements the vanilla OTel demo in `../astrology-app/` — letting you run both side by side and compare instrumentation approaches.

## Vanilla vs Elastic: What's Different?

| | Vanilla OTel Demo (`astrology-app/`) | Elastic OTel Demo (this) |
|--|--------------------------------------|--------------------------|
| **Agents** | Standard OpenTelemetry agents | EDOT (Elastic Distribution of OTel) |
| **Java** | OTel Java agent | Elastic OTel Java agent |
| **.NET** | OTel .NET SDK | Elastic OTel .NET agent |
| **Node.js** | OTel Node.js SDK | Elastic OTel Node.js distribution |
| **Python** | OTel Python SDK | Elastic OTel Python distribution |
| **Collector** | otelcol-contrib (vanilla) | Elastic OTel Collector distribution |
| **Routing** | Services → external collector → Elastic | Services → Elastic collector → Elastic (direct) |
| **Data path** | `host.docker.internal:4317` → your collector | Internal collector in the stack |
| **Auth** | Configured in your `config.yml` | Configured in `.env.override` |
| **Setup** | `docker compose -f docker-compose.app-only.yml up` | `make start` |

**EDOT enrichments** include additional Elastic-specific resource attributes and improved correlation between APM, infrastructure metrics, and logs in the Elastic UI. For standard OTel interoperability with a non-Elastic collector, use the vanilla path.

---

## Prerequisites

- Docker + Docker Compose v2
- `make` (usually pre-installed on macOS/Linux)
- Git
- Elastic credentials:
  - **Elasticsearch endpoint** (e.g. `https://<deployment-id>.es.us-east-1.aws.elastic.cloud:443`)
  - **API key** (Kibana → Stack Management → API Keys → Create API key)

---

## Setup

### 1. Clone the Elastic demo repo

```bash
# From this directory (elastic-otel-demo/)
git clone https://github.com/elastic/opentelemetry-demo.git
cd opentelemetry-demo
```

### 2. Configure your Elastic credentials

Copy the template and fill in your values:

```bash
cp ../.env.override.template .env.override
```

Edit `.env.override`:

```bash
# The Elastic demo sends directly to Elasticsearch — not via the OTLP ingest endpoint.
# Note: this is different from the vanilla collector path (which uses ELASTIC_OTLP_ENDPOINT).
ELASTICSEARCH_ENDPOINT=https://<your-deployment>.es.us-east-1.aws.elastic.cloud:443
ELASTICSEARCH_API_KEY=<your-api-key>
```

### 3. Start the demo

```bash
# From inside the cloned opentelemetry-demo/ directory:
make start
```

Or use the top-level helper (handles clone + config + start in one step):

```bash
cd ..   # back to elastic-otel-demo/
./setup.sh
```

### 4. Access

| UI | URL | Notes |
|----|-----|-------|
| Frontend | `http://localhost:8080` | Change to `:8180` if running alongside vanilla demo |
| Load generator (Locust) | `http://localhost:8089` | Change to `:8189` if running alongside vanilla demo |

---

## Running Alongside the Vanilla Demo

Both demos use ports 8080 (frontend) and 8089 (Locust) by default. To run both simultaneously, offset the Elastic demo's ports.

Add to `.env.override` inside the cloned `opentelemetry-demo/` directory:

```bash
ENVOY_PORT=8180
LOCUST_WEB_PORT=8189
```

Then start as normal. Result:

| Stack | Frontend | Locust |
|-------|----------|--------|
| Vanilla OTel (`astrology-app/`) | `:8080` | `:8089` |
| Elastic OTel (`opentelemetry-demo/`) | `:8180` | `:8189` |

Both stacks send telemetry to Elastic. You can compare service maps, span attributes, and trace quality in APM.

If on EC2, open the additional ports in your security group:

```bash
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxx \
  --protocol tcp --port 8180 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxx \
  --protocol tcp --port 8189 --cidr 0.0.0.0/0
```

---

## Stop

```bash
cd opentelemetry-demo
make stop
# or
docker compose down
```

---

## Troubleshooting

**`make: command not found`**
```bash
# macOS
xcode-select --install
# Ubuntu/Debian
sudo apt install make
```

**No data in Elastic after startup**
- Check `.env.override` has the correct endpoint and credentials
- Run `docker compose logs otel-collector` inside the cloned repo to see exporter errors
- Verify the endpoint URL does not have a trailing slash
- For Serverless: use the OTLP endpoint format, not the Elasticsearch URL

**Port conflicts with vanilla demo**
- Add `ENVOY_PORT=8180` and `LOCUST_WEB_PORT=8189` to `.env.override` (see above)

**Memory issues on small EC2 instances**
- The full stack requires ~8 GB RAM; use a `t3.xlarge` or larger
- The `llm` service (AI review summaries) is the biggest consumer — it can be removed without affecting the core demo

---

## Directory Contents

```
elastic-otel-demo/
├── README.md                  ← This file
├── setup.sh                   ← Clone + configure + launch helper
└── .env.override.template     ← Elastic credentials template
```

The actual Elastic demo code lives at https://github.com/elastic/opentelemetry-demo and is cloned locally (not committed to this repo).
