"""
Sample app: minimal "orders" API with real-ish flow for traces and logs.
Sends OTLP to the collector (no collector changes needed).
Env: OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_SERVICE_NAME
"""
import logging
import os
import time
import uuid
from datetime import datetime
from fastapi import FastAPI, HTTPException
from opentelemetry import trace, _logs
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.resources import Resource
from pydantic import BaseModel

# --- OTLP setup (unchanged: your collector handles the rest) ---
service_name = os.environ.get("OTEL_SERVICE_NAME", "otlp-sample-app")
resource = Resource(attributes={"service.name": service_name})

trace_provider = TracerProvider(resource=resource)
trace_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(trace_provider)
tracer = trace.get_tracer("otlp-sample-app", "1.0.0")

log_provider = LoggerProvider(resource=resource)
log_provider.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter()))
_logs.set_logger_provider(log_provider)
logging.getLogger().addHandler(LoggingHandler(logger_provider=log_provider))
logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger(__name__)

# --- App: in-memory orders (no DB, just for spans/logs) ---
app = FastAPI(title="OTLP Sample App – Orders", version="1.0.0")

orders: dict[str, dict] = {}


class CreateOrder(BaseModel):
    item: str
    quantity: int = 1


def _validate_order(payload: CreateOrder) -> None:
    with tracer.start_as_current_span("validate_order") as span:
        span.set_attribute("order.item", payload.item)
        span.set_attribute("order.quantity", payload.quantity)
        if payload.quantity < 1:
            logger.warning("Order rejected: quantity < 1", extra={"quantity": payload.quantity})
            raise HTTPException(status_code=400, detail="quantity must be >= 1")
        logger.info("Order validated", extra={"item": payload.item, "quantity": payload.quantity})


def _persist_order(order_id: str, payload: CreateOrder) -> dict:
    with tracer.start_as_current_span("persist_order") as span:
        span.set_attribute("order.id", order_id)
        # Simulate a tiny bit of work
        time.sleep(0.02)
        record = {
            "id": order_id,
            "item": payload.item,
            "quantity": payload.quantity,
            "status": "created",
            "created_at": datetime.utcnow().isoformat() + "Z",
        }
        orders[order_id] = record
        logger.info("Order persisted", extra={"order_id": order_id, "item": payload.item})
        return record


@app.post("/orders")
def create_order(payload: CreateOrder):
    with tracer.start_as_current_span("create_order") as span:
        span.set_attribute("http.method", "POST")
        span.set_attribute("http.route", "/orders")
        _validate_order(payload)
        order_id = str(uuid.uuid4())[:8]
        record = _persist_order(order_id, payload)
        return record


@app.get("/orders")
def list_orders(limit: int = 10):
    with tracer.start_as_current_span("list_orders") as span:
        span.set_attribute("query.limit", limit)
        items = list(orders.values())[-limit:]
        logger.info("List orders", extra={"count": len(items), "limit": limit})
        return {"orders": items, "count": len(items)}


@app.get("/orders/{order_id}")
def get_order(order_id: str):
    with tracer.start_as_current_span("get_order") as span:
        span.set_attribute("order.id", order_id)
        if order_id not in orders:
            logger.warning("Order not found", extra={"order_id": order_id})
            raise HTTPException(status_code=404, detail="Order not found")
        logger.info("Order retrieved", extra={"order_id": order_id})
        return orders[order_id]


@app.post("/orders/{order_id}/complete")
def complete_order(order_id: str):
    with tracer.start_as_current_span("complete_order") as span:
        span.set_attribute("order.id", order_id)
        if order_id not in orders:
            logger.warning("Complete failed: order not found", extra={"order_id": order_id})
            raise HTTPException(status_code=404, detail="Order not found")
        orders[order_id]["status"] = "completed"
        orders[order_id]["completed_at"] = datetime.utcnow().isoformat() + "Z"
        logger.info("Order completed", extra={"order_id": order_id})
        return orders[order_id]
