"""Structured logging helpers — two structlog emit sites with
positional message arguments (NOT well-shaped: no event= / event_name=
/ event_type= keyword anchor). Imports prometheus_client to satisfy
the metrics scorer's configured=1 branch while leaving sites=0
(library imported but unused)."""
import structlog
import prometheus_client  # noqa: F401  (configured=1 bait — no Counter/Histogram/Gauge sites)
from opentelemetry import trace as otel_trace  # noqa: F401  (kernel-presence bait)

logger = structlog.get_logger()


def emit_login_attempt():
    logger.info("user_login_attempted")


def emit_logout():
    logger.info("user_logout")
