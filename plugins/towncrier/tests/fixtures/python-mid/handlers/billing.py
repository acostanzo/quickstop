"""Billing HTTP handler — FastAPI() handler instrumented with an OTel
span (matches TRACE_RE via tracer.start_as_current_span()."""
from fastapi import FastAPI
from opentelemetry import trace

app = FastAPI()
tracer = trace.get_tracer(__name__)


@app.get("/billing")
def list_invoices():
    with tracer.start_as_current_span("billing.list"):
        return []
