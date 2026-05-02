from opentelemetry.metrics import get_meter

meter = get_meter("my-app")
request_counter = meter.create_counter("requests_total")
latency_histogram = meter.create_histogram("latency_seconds")
active_gauge = meter.create_up_down_counter("active_connections")
