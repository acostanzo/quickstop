import structlog

logger = structlog.get_logger()


def primary_path():
    logger.info("event_one")
    logger.warning("event_two")
    logger.error("event_three")


def fallback_path():
    print("fallback_one")
    print("fallback_two")
    print("fallback_three")
    print("fallback_four")
    print("fallback_five")
    print("fallback_six")
    print("fallback_seven")
