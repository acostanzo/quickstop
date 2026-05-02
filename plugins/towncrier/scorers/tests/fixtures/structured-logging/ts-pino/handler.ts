import pino from "pino";

const logger = pino();

export function handle() {
  logger.info({ event: "ok" });
  logger.warn({ event: "slow" });
  logger.error({ event: "fail" });
  logger.debug({ event: "trace" });
}
