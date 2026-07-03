const express = require("express");
const { Pool } = require("pg");
const app = express();
app.use(express.json());

const pool = new Pool({
  host: "${db_fqdn}", user: "psqladmin", password: "${db_password}",
  database: "postgres", port: 5432, ssl: { rejectUnauthorized: false }
});

async function init() {
  await pool.query("CREATE TABLE IF NOT EXISTS messages (id SERIAL PRIMARY KEY, content TEXT)");
  await pool.query("INSERT INTO messages (content) SELECT 'Hello from PostgreSQL ' WHERE NOT EXISTS (SELECT 1 FROM messages)");
}

app.get("/api/messages", async (req, res) => {
  const r = await pool.query("SELECT content FROM messages ORDER BY id DESC");
  res.json(r.rows);
});

app.post("/api/messages", async (req, res) => {
  await pool.query("INSERT INTO messages (content) VALUES ($1)", [req.body.content]);
  res.json({ ok: true });
});

init().then(() => app.listen(3000, () => console.log("API on :3000")));