# Roll Your Own — Event Emission / Observability

How to achieve the `event-emission` dimension's readiness without installing the forthcoming `towncrier` `:audit` extension.

Towncrier's `:audit` extension (Phase 2+) is the recommended depth auditor for observability posture. Until it ships, this document covers the manual bar.

## What "good" looks like

- **Structured logging** — lines are JSON (or logfmt), not free-text "printf debugging." Each line has a stable schema: `level`, `ts`, `event`, plus typed context fields.
- **Trace propagation** — cross-service requests carry a trace-id. OpenTelemetry's W3C headers (`traceparent`, `tracestate`) are the baseline.
- **Metrics** — counters + histograms for the operations the business actually cares about. Not "every function call."
- **Events for state transitions** — the domain-level "an order was placed," "a user was locked out," "a deploy rolled back." Emit once, consume many times.
- **Sensitive data masked at emission.** No tokens, no PII, no secrets in logs or traces. Mask at the call site; don't rely on downstream filtering.

## Minimum viable setup

### Structured logging (Python)

```python
import logging
import json

class JSONFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({
            "ts": self.formatTime(record),
            "level": record.levelname,
            "event": record.name,
            "message": record.getMessage(),
            **getattr(record, "context", {}),
        })

logging.basicConfig(handlers=[logging.StreamHandler()], level=logging.INFO)
logging.getLogger().handlers[0].setFormatter(JSONFormatter())
```

Or use `structlog` / `loguru` — both produce JSON output out of the box.

### Structured logging (TypeScript)

```ts
import pino from "pino";
const log = pino({
  timestamp: pino.stdTimeFunctions.isoTime,
  formatters: { level: (label) => ({ level: label }) },
});
log.info({ event: "order.placed", order_id }, "order placed");
```

Or `winston` / `bunyan`. Pino is fast and the least ceremony.

### OpenTelemetry tracing

Install the OTel SDK for your language; configure an exporter (OTLP to a collector, or direct to a vendor).

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="http://otel-collector:4317"))
)
```

Wrap the entry points of your service in spans; context propagates automatically through supported libraries.

### Domain event emission

```python
def emit_event(event_name: str, **fields):
    log.info({"event": event_name, **fields}, event_name)

emit_event("user.locked_out", user_id=user.id, reason="failed_login_threshold")
```

Consume the resulting log stream with your existing pipeline (journald, Loki, Datadog, CloudWatch, etc.).

## Periodic audit checklist

- Every log line structured? Or free-text snuck back in?
- Sensitive fields masked at emission? (Grep for known secret-field names against the log schema.)
- Trace-id present in error logs? When a user reports an error, can you pivot from log → trace → related logs in under a minute?
- Business-level metrics track the handful of things the business cares about, not the catalog of every method?

## Common anti-patterns

- **`print` / `console.log` in production code.** Unstructured, untimestamped, unsearchable.
- **Log-everything firehose.** More logs doesn't equal more visibility. Emit at decision points.
- **Metrics named after implementation detail.** `http_handler_ms` is less useful than `order_placement_latency_ms`.
- **PII in logs.** "Just mask it at the sink" is a security incident waiting.

## Presence check pronto uses

Pronto's kernel presence check for this dimension greps source for any of: `opentelemetry`, `OTEL_`, `tracer`, `metric`, `event_bus`, `eventbus`, `emit(`, `structlog`, `pino`, `winston`, `logrus`. Presence-cap is 50 until towncrier's `:audit` extension ships or a depth audit runs.

## Concrete first step

Pick one boundary in your system — the request-handler entry point, the worker main loop, the database call — and emit one structured event per pass through it, with a trace-id field. That single integration proves the pipeline end-to-end and gives the rest of the codebase a template.
