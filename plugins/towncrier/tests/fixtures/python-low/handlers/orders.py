"""Orders HTTP handler — matches HANDLER_RE via FastAPI(); zero
trace-context references."""
from fastapi import FastAPI

app = FastAPI()


@app.get("/orders")
def list_orders():
    return []


@app.post("/orders")
def create_order():
    return {}
