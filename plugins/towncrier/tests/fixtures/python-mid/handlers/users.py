"""Users HTTP handler — FastAPI() handler with no trace-context
references. One of the three handler-shaped files; this one keeps
trace-propagation-ratio at 2/3 = 0.67 by NOT carrying a span."""
from fastapi import FastAPI

app = FastAPI()


@app.get("/users")
def list_users():
    return []
