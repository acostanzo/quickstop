from .main import app
from opentelemetry import trace


@app.get("/users")
def list_users():
    span = trace.get_current_span()
    return {"span_id": str(span.get_span_context().span_id)}


@app.post("/users")
def create_user():
    span = trace.get_current_span()
    span.set_attribute("entity", "user")
    return {}
