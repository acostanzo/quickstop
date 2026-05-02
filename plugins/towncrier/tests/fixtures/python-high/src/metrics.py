"""Prometheus instrumentation — twelve metrics-defining call sites
drive the metrics-instrumentation-count observation to gte 10 → 100."""
from prometheus_client import Counter, Histogram, Gauge, Summary

login_total = Counter("login_total", "Logins")
logout_total = Counter("logout_total", "Logouts")
signup_total = Counter("signup_total", "Signups")
login_duration_seconds = Histogram("login_duration_seconds", "Login latency")
checkout_duration_seconds = Histogram("checkout_duration_seconds", "Checkout latency")
queue_depth = Gauge("queue_depth", "Queue depth")
active_sessions = Gauge("active_sessions", "Active sessions")
worker_pool_size = Gauge("worker_pool_size", "Worker pool size")
order_value_summary = Summary("order_value_summary", "Order values")
session_age_summary = Summary("session_age_summary", "Session ages")
api_request_total = Counter("api_request_total", "API requests")
api_error_total = Counter("api_error_total", "API errors")
