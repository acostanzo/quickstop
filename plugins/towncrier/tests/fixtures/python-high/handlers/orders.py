"""Orders HTTP handler — FastAPI() handler with OTel trace span."""
from fastapi import FastAPI
from opentelemetry import trace

app = FastAPI()
tracer = trace.get_tracer(__name__)


@app.get("/orders")
def list_orders():
    with tracer.start_as_current_span("orders.list"):
        return []
