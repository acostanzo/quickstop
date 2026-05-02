"""Structured logging helpers — five structlog emit sites; four carry
an event keyword anchor (well-shaped), one is positional (NOT well-
shaped). Drives event-schema-consistency-ratio to 4 of 5 = 0.80 →
gte 0.80 → 85."""
import structlog

logger = structlog.get_logger()


def emit_order_placed(amount):
    logger.info(event="order_placed", amount=amount)


def emit_order_shipped(order_id):
    logger.info(event="order_shipped", order_id=order_id)


def emit_order_paid():
    logger.info(event="order_paid")


def emit_order_refunded():
    logger.info(event="order_refunded")


def emit_order_cancelled():
    logger.info("order_cancelled")
