import express from "express";
import { trace } from "@opentelemetry/api";

const app = express();

app.get("/items", (_req, res) => {
  const span = trace.getActiveSpan();
  res.json({ span_id: span?.spanContext().spanId });
});

app.post("/items", (_req, res) => {
  const span = trace.getActiveSpan();
  span?.setAttribute("op", "create");
  res.json({});
});
