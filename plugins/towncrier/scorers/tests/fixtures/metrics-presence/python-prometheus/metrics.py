from prometheus_client import Counter, Histogram, Gauge

REQUESTS_TOTAL = Counter("requests_total", "Total requests")
LATENCY_SECONDS = Histogram("latency_seconds", "Request latency")
ACTIVE_CONNECTIONS = Gauge("active_connections", "Active connections")
