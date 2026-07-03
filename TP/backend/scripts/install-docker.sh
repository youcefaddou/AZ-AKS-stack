#!/bin/bash
set -e

apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

# Clé GPG officielle Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Dépôt Docker stable (Debian)
ARCH=$$(dpkg --print-architecture)
. /etc/os-release
echo "deb [arch=$$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $$VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Démarrage automatique
systemctl enable docker
systemctl start docker

# L'utilisateur admin peut lancer docker sans sudo
usermod -aG docker ${admin_username}
