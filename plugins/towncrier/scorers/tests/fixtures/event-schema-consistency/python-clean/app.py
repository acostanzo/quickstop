import structlog

logger = structlog.get_logger()


def fn():
    logger.info("e1", event="user.created", user_id=1)
    logger.info("e2", event="user.deleted", user_id=2)
    logger.info("e3", event="order.placed", order_id=3)
