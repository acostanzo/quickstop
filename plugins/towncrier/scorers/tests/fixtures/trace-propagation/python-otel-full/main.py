from fastapi import FastAPI
from opentelemetry import trace

app = FastAPI()
tracer = trace.get_tracer(__name__)


@app.get("/items")
def list_items():
    with tracer.start_as_current_span("list_items"):
        return {"ok": True}


@app.post("/items")
def create_item():
    span = trace.get_current_span()
    span.set_attribute("op", "create")
    return {}
