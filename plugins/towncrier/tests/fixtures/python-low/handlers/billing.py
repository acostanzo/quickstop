"""Billing HTTP handler — matches HANDLER_RE via FastAPI(); zero
trace-context references."""
from fastapi import FastAPI

app = FastAPI()


@app.get("/billing")
def list_invoices():
    return []


@app.post("/billing/charge")
def charge_card():
    return {}
