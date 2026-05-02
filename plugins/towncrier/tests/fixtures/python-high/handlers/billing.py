"""Billing HTTP handler — FastAPI() handler with OTel trace span."""
from fastapi import FastAPI
from opentelemetry import trace

app = FastAPI()
tracer = trace.get_tracer(__name__)


@app.get("/billing")
def list_invoices():
    with tracer.start_as_current_span("billing.list"):
        return []
