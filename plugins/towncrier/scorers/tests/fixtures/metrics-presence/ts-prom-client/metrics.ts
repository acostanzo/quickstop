import { Counter, Histogram, Gauge } from "prom-client";

export const requestsTotal = new Counter({ name: "requests_total", help: "" });
export const latencySeconds = new Histogram({ name: "latency_seconds", help: "" });
export const activeConnections = new Gauge({ name: "active_connections", help: "" });

export function recordLatency(value: number) {
  latencySeconds.observe(value);
}
