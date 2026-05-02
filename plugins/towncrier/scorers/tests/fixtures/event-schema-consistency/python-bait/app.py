import structlog

logger = structlog.get_logger()


def good():
    logger.info("e1", event="user.created", user_id=1)
    logger.info("e2", event="user.updated", user_id=2)
    logger.info("e3", event="order.placed", order_id=3)


def freeform():
    logger.info("just a message")
    logger.info("another message", user_id=1)
    logger.info("third message")
    logger.warning("warning fired")
    logger.error("something failed")
    logger.debug("trace info")
    logger.info("more text")
