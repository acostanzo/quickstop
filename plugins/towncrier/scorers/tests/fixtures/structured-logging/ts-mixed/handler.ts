import pino from "pino";

const logger = pino();

export function handle() {
  logger.info({ event: "ok" });
  logger.warn({ event: "slow" });
  logger.error({ event: "fail" });
  logger.debug({ event: "trace" });
  console.log("debug_one");
  console.log("debug_two");
  console.error("err_one");
  console.error("err_two");
  console.warn("warn_one");
  console.warn("warn_two");
}
