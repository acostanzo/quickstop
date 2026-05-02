import express from "express";

const app = express();

app.get("/items", (_req, res) => {
  res.json({ ok: true });
});

app.post("/items", (_req, res) => {
  res.json({ ok: true });
});
