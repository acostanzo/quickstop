import structlog

logger = structlog.get_logger()


def handle_request():
    logger.info("request_received")
    logger.warning("slow_path")
    logger.error("downstream_failure")
    logger.debug("trace_state")
    logger.critical("fatal_condition")
