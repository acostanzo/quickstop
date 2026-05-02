"""Prometheus instrumentation — five metrics-defining call sites
(Counter, Histogram, Gauge, Summary, Counter) drive the metrics-
instrumentation-count observation to gte 3 → 85."""
from prometheus_client import Counter, Histogram, Gauge, Summary

login_attempts_total = Counter("login_attempts_total", "Login attempts")
login_duration_seconds = Histogram("login_duration_seconds", "Login latency")
active_sessions = Gauge("active_sessions", "Active session count")
order_value_summary = Summary("order_value", "Order value summary")
checkout_attempts_total = Counter("checkout_attempts_total", "Checkout attempts")
