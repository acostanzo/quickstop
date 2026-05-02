import pino from "pino";
const logger = pino();

export function handle() {
  logger.info({ event: "user.created", userId: 1 });
  logger.info({ event: "user.updated", userId: 2 });
  logger.info({ event: "order.placed", orderId: 3 });
  logger.info("freeform 1");
  logger.info("freeform 2");
  logger.warn("freeform 3");
  logger.warn("freeform 4");
  logger.error("freeform 5");
  logger.debug("freeform 6");
  logger.info("freeform 7");
}
