#!/bin/bash
set -e

# Install Docker if not already present
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  ARCH=$(dpkg --print-architecture)
  . /etc/os-release
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  systemctl enable docker
  systemctl start docker
fi

# Stop old Node.js service if it was running
systemctl stop guestbook 2>/dev/null || true
systemctl disable guestbook 2>/dev/null || true

# Remove old container if exists
docker rm -f api 2>/dev/null || true

mkdir -p /opt/api && cd /opt/api

cat > server.js << 'JS'
const express = require("express");
const { Pool } = require("pg");
const app = express();
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_FQDN,
  user: "psqladmin",
  password: process.env.DB_PASSWORD,
  database: "postgres",
  port: 5432,
  ssl: { rejectUnauthorized: false }
});

async function init() {
  await pool.query("CREATE TABLE IF NOT EXISTS messages (id SERIAL PRIMARY KEY, content TEXT)");
  await pool.query("INSERT INTO messages (content) SELECT 'Hello from PostgreSQL 👋' WHERE NOT EXISTS (SELECT 1 FROM messages)");
}

app.get("/health", (req, res) => res.sendStatus(200));

app.get("/api/messages", async (req, res) => {
  const r = await pool.query("SELECT content FROM messages ORDER BY id DESC");
  res.json(r.rows);
});

app.post("/api/messages", async (req, res) => {
  await pool.query("INSERT INTO messages (content) VALUES ($1)", [req.body.content]);
  res.json({ ok: true });
});

init().then(() => app.listen(3000, () => console.log("API on :3000")));
JS

cat > package.json << 'JSON'
{"name":"api","version":"1.0.0","dependencies":{"express":"^4","pg":"^8"}}
JSON

cat > Dockerfile << 'DOCKERFILE'
FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install --production
COPY server.js .
EXPOSE 3000
CMD ["node", "server.js"]
DOCKERFILE

docker build -t api .
docker run -d --restart=always --name api \
  --network host \
  -e DB_FQDN=${db_fqdn} \
  -e DB_PASSWORD=${db_password} \
  api