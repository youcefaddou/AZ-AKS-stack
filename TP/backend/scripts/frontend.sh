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

# Stop old nginx if running
systemctl stop nginx 2>/dev/null || true

# Remove old container if exists
docker rm -f frontend 2>/dev/null || true

mkdir -p /opt/frontend && cd /opt/frontend

cat > index.html << 'HTML'
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Cloud Ops Board</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #0d1117; color: #e6edf3; font-family: 'Segoe UI', system-ui, sans-serif; min-height: 100vh; }
    header { background: linear-gradient(135deg, #161b22 0%, #1f2937 100%); border-bottom: 1px solid #30363d; padding: 24px 32px; display: flex; align-items: center; gap: 16px; }
    .logo { width: 42px; height: 42px; background: linear-gradient(135deg, #3b82f6, #06b6d4); border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 22px; }
    header h1 { font-size: 1.4rem; font-weight: 600; }
    header p { font-size: 0.8rem; color: #8b949e; margin-top: 2px; }
    .badge { margin-left: auto; background: #1a3a1a; color: #3fb950; border: 1px solid #2ea043; padding: 4px 12px; border-radius: 20px; font-size: 0.75rem; display: flex; align-items: center; gap: 6px; }
    .dot { width: 7px; height: 7px; background: #3fb950; border-radius: 50%; animation: pulse 2s infinite; }
    @keyframes pulse { 0%,100%%{opacity:1} 50%%{opacity:0.3} }
    main { max-width: 760px; margin: 40px auto; padding: 0 24px; }
    .card { background: #161b22; border: 1px solid #30363d; border-radius: 12px; padding: 24px; margin-bottom: 24px; }
    .card h2 { font-size: 0.85rem; text-transform: uppercase; letter-spacing: 1px; color: #8b949e; margin-bottom: 16px; }
    form { display: flex; gap: 10px; }
    input { flex: 1; background: #0d1117; border: 1px solid #30363d; border-radius: 8px; color: #e6edf3; padding: 10px 14px; font-size: 0.95rem; outline: none; transition: border-color 0.2s; }
    input:focus { border-color: #3b82f6; }
    input::placeholder { color: #484f58; }
    button { background: linear-gradient(135deg, #3b82f6, #06b6d4); color: white; border: none; border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; font-weight: 600; cursor: pointer; transition: opacity 0.2s; white-space: nowrap; }
    button:hover { opacity: 0.85; }
    .log-entry { display: flex; align-items: flex-start; gap: 12px; padding: 12px 0; border-bottom: 1px solid #21262d; }
    .log-entry:last-child { border-bottom: none; }
    .log-icon { width: 30px; height: 30px; min-width: 30px; background: #1c2b3a; border: 1px solid #3b82f6; border-radius: 6px; display: flex; align-items: center; justify-content: center; font-size: 14px; }
    .log-meta { font-size: 0.75rem; color: #3b82f6; margin-bottom: 3px; font-family: monospace; }
    .log-text { font-size: 0.95rem; color: #e6edf3; }
    .empty { color: #484f58; font-style: italic; text-align: center; padding: 20px 0; }
    .tier-info { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 24px; }
    .tier { background: #161b22; border: 1px solid #30363d; border-radius: 10px; padding: 16px; text-align: center; }
    .tier .icon { font-size: 24px; margin-bottom: 8px; }
    .tier .name { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 1px; color: #8b949e; }
    .tier .val { font-size: 0.85rem; color: #e6edf3; margin-top: 4px; }
  </style>
</head>
<body>
  <header>
    <div class="logo">☁️</div>
    <div>
      <h1>Cloud Ops Board</h1>
      <p>Architecture n-tier · Azure</p>
    </div>
    <div class="badge"><div class="dot"></div> Online</div>
  </header>
  <main>
    <div class="tier-info">
      <div class="tier"><div class="icon">🌐</div><div class="name">Frontend</div><div class="val">Nginx · Docker</div></div>
      <div class="tier"><div class="icon">⚙️</div><div class="name">Backend</div><div class="val">Node.js · Docker</div></div>
      <div class="tier"><div class="icon">🗄️</div><div class="name">Database</div><div class="val">PostgreSQL · Azure</div></div>
    </div>
    <div class="card">
      <h2>📡 Envoyer un message</h2>
      <form id="f">
        <input id="msg" placeholder="Votre message..." required autocomplete="off">
        <button type="submit">Publier</button>
      </form>
    </div>
    <div class="card">
      <h2>📋 Messages</h2>
      <div id="list"><div class="empty">Chargement...</div></div>
    </div>
  </main>
  <script>
    var icons = ['💬','🚀','✨','🔧','📦','🌍','⚡','🛠️'];
    function load() {
      fetch('/api/messages')
        .then(function(r){ return r.json(); })
        .then(function(rows) {
          if (!rows.length) { document.getElementById('list').innerHTML = '<div class="empty">Aucun message pour l\'instant.</div>'; return; }
          document.getElementById('list').innerHTML = rows.map(function(m, i) {
            return '<div class="log-entry"><div class="log-icon">' + icons[i % icons.length] + '</div>'
              + '<div><div class="log-meta">[MSG-' + String(i+1).padStart(3,'0') + '] cloud-ops-board</div>'
              + '<div class="log-text">' + m.content.replace(/</g,'&lt;') + '</div></div></div>';
          }).join('');
        });
    }
    document.getElementById('f').onsubmit = function(e) {
      e.preventDefault();
      fetch('/api/messages', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({content: document.getElementById('msg').value}) })
        .then(function() { document.getElementById('msg').value = ''; load(); });
    };
    load();
  </script>
</body>
</html>
HTML

cat > Dockerfile << 'DOCKERFILE'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
DOCKERFILE

docker build -t frontend .
docker run -d --restart=always --name frontend -p 80:80 frontend