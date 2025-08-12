#!/bin/bash
set -euo pipefail

ts() { date +"[%Y-%m-%d %H:%M:%S]"; }

CLUSTER_CONFIG="cluster_config.yml"
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_github}"   # clé utilisée depuis l'admin vers tous les nœuds

# ----- Lire la conf cluster -----
MASTER_IP=$(yq e '.nodes.master.ip' "$CLUSTER_CONFIG")
MASTER_USER=$(yq e '.nodes.master.user' "$CLUSTER_CONFIG")
mapfile -t WORKERS_IPS < <(yq e '.nodes.workers[].ip' "$CLUSTER_CONFIG")
mapfile -t WORKERS_USERS < <(yq e '.nodes.workers[].user' "$CLUSTER_CONFIG")

# ----- Helpers -----
ssh_node() {
  local user="$1" ip="$2" cmd="$3"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$user@$ip" "$cmd"
}

scp_node() {
  local src="$1" user="$2" ip="$3" dst="$4"
  scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$src" "$user@$ip:$dst"
}

prepare_node() {
  local ip="$1" user="$2"
  echo "$(ts) Préparation node $user@$ip"
  ssh_node "$user" "$ip" '
    set -e
    if ! command -v yq >/dev/null 2>&1; then
      wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O yq
      chmod +x yq && sudo mv yq /usr/local/bin/yq
    fi
    if ! command -v docker >/dev/null 2>&1; then
      sudo apt-get update -y
      sudo apt-get install -y ca-certificates curl gnupg lsb-release
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      sudo apt-get update -y
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo systemctl enable --now docker
    fi
  '
}

ensure_swarm_init() {
  echo "$(ts) Initialisation du Swarm (master=$MASTER_IP)"
  ssh_node "$MASTER_USER" "$MASTER_IP" '
    set -e
    if ! sudo docker info 2>/dev/null | grep -q "Swarm: active"; then
      sudo docker swarm init --advertise-addr '"$MASTER_IP"'
    else
      # Si actif mais pas manager, tenter de rejoindre comme manager (cas rare)
      true
    fi
  '
}

join_workers() {
  echo "$(ts) Join des workers"
  local token
  token=$(ssh_node "$MASTER_USER" "$MASTER_IP" "sudo docker swarm join-token worker -q")
  for i in "${!WORKERS_IPS[@]}"; do
    local ip="${WORKERS_IPS[$i]}" user="${WORKERS_USERS[$i]}"
    echo "$(ts)  -> $user@$ip"
    ssh_node "$user" "$ip" '
      set -e
      if sudo docker info 2>/dev/null | grep -q "Swarm: active"; then
        # déjà dans un swarm, si besoin leave puis join
        if ! sudo docker node ls >/dev/null 2>&1; then
          # worker (pas manager), on peut leave en force sans casser le cluster
          sudo docker swarm leave --force || true
        fi
      fi
      if ! sudo docker info 2>/dev/null | grep -q "Swarm: active"; then
        sudo docker swarm join --token '"$token"' '"$MASTER_IP"':2377
      fi
    ' || echo "$(ts)    (déjà joint ou échec non bloquant)"
  done
}

deploy_stack() {
  echo "$(ts) Déploiement du stack 'littlepigs'"
  # Copier les fichiers nécessaires sur le master
  scp_node "$CLUSTER_CONFIG" "$MASTER_USER" "$MASTER_IP" "~/"
  scp_node "docker-compose.yml" "$MASTER_USER" "$MASTER_IP" "~/"

  # Déployer
  ssh_node "$MASTER_USER" "$MASTER_IP" '
    set -e
    sudo docker stack deploy -c ~/docker-compose.yml littlepigs
  '
}

post_fix_nginx_frontend() {
  echo "$(ts) Post-déploiement: fix nginx & frontend (tmpfs + read_only=false + user root)"
  ssh_node "$MASTER_USER" "$MASTER_IP" '
    set -e

    unpause_if_needed() {
      local svc="$1"
      # si update est en pause, tenter rollback silencieux
      if sudo docker service inspect "$svc" --format "{{.UpdateStatus.State}}" 2>/dev/null | grep -q "paused"; then
        sudo docker service update --rollback "$svc" || true
      fi
    }

    safe_update_nginxish() {
      local svc="$1"
      unpause_if_needed "$svc"

      # Appliquer les réglages nécessaires (idempotent)
      sudo docker service update \
        --read-only=false \
        --user root \
        --mount-add type=tmpfs,destination=/var/cache/nginx,tmpfs-size=67108864 \
        --mount-add type=tmpfs,destination=/var/run,tmpfs-size=16777216 \
        --force \
        "$svc" || true
    }

    safe_update_nginxish littlepigs_nginx
    safe_update_nginxish littlepigs_frontend

    echo "Attente que les tasks passent en Running..."
    deadline=$((SECONDS+180))
    while true; do
      # On veut zéro "Failed" récent sur nginx et frontend
      bad=$( (sudo docker service ps littlepigs_nginx --no-trunc || true; sudo docker service ps littlepigs_frontend --no-trunc || true) | grep -c "Failed" || true )
      if [ "$bad" -eq 0 ]; then
        # Et au moins une task Running sur chaque service
        okn=$(sudo docker service ps littlepigs_nginx --filter desired-state=running --format "{{.CurrentState}}" | grep -c Running || true)
        okf=$(sudo docker service ps littlepigs_frontend --filter desired-state=running --format "{{.CurrentState}}" | grep -c Running || true)
        if [ "$okn" -ge 1 ] && [ "$okf" -ge 1 ]; then
          echo "Services OK (nginx=$okn, frontend=$okf)."
          break
        fi
      fi
      if [ $SECONDS -ge $deadline ]; then
        echo "Timeout d’attente des services. Derniers états:"
        sudo docker service ps littlepigs_nginx --no-trunc || true
        sudo docker service ps littlepigs_frontend --no-trunc || true
        exit 1
      fi
      sleep 3
    done
  '
}

echo "$(ts) Démarrage du déploiement cluster…"
prepare_node "$MASTER_IP" "$MASTER_USER"
for i in "${!WORKERS_IPS[@]}"; do
  prepare_node "${WORKERS_IPS[$i]}" "${WORKERS_USERS[$i]}"
done

ensure_swarm_init
join_workers
deploy_stack
post_fix_nginx_frontend
echo "$(ts) Déploiement terminé."
