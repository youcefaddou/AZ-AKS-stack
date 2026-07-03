const express = require("express");
const { Pool } = require("pg");
const promClient = require("prom-client");

const app = express();
app.use(express.json());

// --- Prometheus metrics ---
const register = promClient.register;
promClient.collectDefaultMetrics({ register });

const httpRequestsTotal = new promClient.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "path", "status"],
  registers: [register],
});

const httpRequestDuration = new promClient.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "path", "status"],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2],
  registers: [register],
});

// Middleware pour mesurer chaque requête
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on("finish", () => {
    const labels = {
      method: req.method,
      path: req.path,
      status: res.statusCode,
    };
    httpRequestsTotal.inc(labels);
    end(labels);
  });
  next();
});

// --- PostgreSQL ---
const pool = new Pool({
  host: process.env.DB_FQDN || "localhost",
  user: "psqladmin",
  password: process.env.DB_PASSWORD,
  database: "postgres",
  port: 5432,
  ssl: process.env.DB_SSL === "false" ? false : { rejectUnauthorized: false },
});

async function init() {
  await pool.query(
    "CREATE TABLE IF NOT EXISTS messages (id SERIAL PRIMARY KEY, content TEXT)",
  );
  await pool.query(
    "INSERT INTO messages (content) SELECT 'Hello from PostgreSQL 👋' WHERE NOT EXISTS (SELECT 1 FROM messages)",
  );
}

// --- Routes ---
app.get("/api/messages", async (req, res) => {
  const r = await pool.query("SELECT content FROM messages ORDER BY id DESC");
  res.json(r.rows);
});

app.post("/api/messages", async (req, res) => {
  await pool.query("INSERT INTO messages (content) VALUES ($1)", [
    req.body.content,
  ]);
  res.json({ ok: true });
});

// Endpoint métriques Prometheus
app.get("/metrics", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

init().then(() => app.listen(3000, () => console.log("API on :3000")));
