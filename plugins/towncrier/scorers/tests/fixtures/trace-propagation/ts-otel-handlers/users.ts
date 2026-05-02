import express from "express";
import { propagation } from "@opentelemetry/api";

const router = express();

router.post("/users", (req, res) => {
  const carrier: Record<string, string> = {};
  propagation.inject({} as any, carrier);
  res.json({ headers: carrier });
});
