"""Users HTTP handler — matches HANDLER_RE via FastAPI(); zero
trace-context references."""
from fastapi import FastAPI

app = FastAPI()


@app.get("/users")
def list_users():
    return []


@app.post("/users")
def create_user():
    return {}
