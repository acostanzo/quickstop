"""Users HTTP handler — FastAPI() handler with OTel trace span."""
from fastapi import FastAPI
from opentelemetry import trace

app = FastAPI()
tracer = trace.get_tracer(__name__)


@app.get("/users")
def list_users():
    with tracer.start_as_current_span("users.list"):
        return []
