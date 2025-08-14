#!/bin/bash
set -euo pipefail

CLUSTER_CONFIG="cluster_config.yml"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_github}"

MASTER_IP=$(yq e '.nodes.master.ip' "$CLUSTER_CONFIG")
MASTER_USER=$(yq e '.nodes.master.user' "$CLUSTER_CONFIG")
readarray -t WORKERS_IPS   < <(yq e '.nodes.workers[].ip' "$CLUSTER_CONFIG")
readarray -t WORKERS_USERS < <(yq e '.nodes.workers[].user' "$CLUSTER_CONFIG")

SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

scp $SSH_OPTS "$CLUSTER_CONFIG" "$MASTER_USER@$MASTER_IP:~/"
scp $SSH_OPTS docker-compose.yml "$MASTER_USER@$MASTER_IP:~/"

prepare_node() {
  local ip="$1" user="$2"
  ssh $SSH_OPTS "$user@$ip" bash -s <<'EOS'
set -euo pipefail

if ! command -v yq >/dev/null 2>&1; then
  wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O yq
  chmod +x yq && sudo mv yq /usr/local/bin/yq
fi

if [ -x /usr/bin/docker.disabled ] && [ ! -x /usr/bin/docker ]; then
  sudo mv /usr/bin/docker.disabled /usr/bin/docker
fi

if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y --reinstall docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

sudo systemctl enable docker >/dev/null 2>&1 || true
sudo systemctl start docker || true

docker --version
EOS
}

prepare_node "$MASTER_IP" "$MASTER_USER"
for i in "${!WORKERS_IPS[@]}"; do
  prepare_node "${WORKERS_IPS[$i]}" "${WORKERS_USERS[$i]}"
done

init_swarm() {
  ssh $SSH_OPTS "$MASTER_USER@$MASTER_IP" bash -s -- "$MASTER_IP" <<'EOS'
set -euo pipefail
MASTER_IP="$1"
if ! sudo docker info 2>/dev/null | grep -q 'Swarm: active'; then
  sudo docker swarm init --advertise-addr "$MASTER_IP"
fi
echo "[SWARM] master actif"
EOS
}

join_workers() {
  local token
  token=$(ssh $SSH_OPTS "$MASTER_USER@$MASTER_IP" "sudo docker swarm join-token worker -q")
  for i in "${!WORKERS_IPS[@]}"; do
    local ip="${WORKERS_IPS[$i]}" user="${WORKERS_USERS[$i]}"
    ssh $SSH_OPTS "$user@$ip" "sudo docker swarm join --token $token $MASTER_IP:2377" \
      || echo "[WARN] Worker $ip déjà joint ou indisponible"
  done
}

deploy_stack() {
  ssh $SSH_OPTS "$MASTER_USER@$MASTER_IP" "sudo docker stack deploy -c ~/docker-compose.yml littlepigs"
  echo "[DEPLOY] stack 'littlepigs' déployé"
}

echo "Starting cluster deployment..."
init_swarm
join_workers
deploy_stack
echo "Deployment complete."
