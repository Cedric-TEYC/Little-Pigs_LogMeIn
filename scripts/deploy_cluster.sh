#!/bin/bash
set -euo pipefail

CLUSTER_CONFIG="cluster_config.yml"
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_github}" # Utilise toujours cette clé, override possible via env
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no"

log() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

ssh_run() {
  local user_host="$1"; shift
  ssh $SSH_OPTS "$user_host" "$@"
}

scp_put() {
  local src="$1" dst="$2"
  scp $SSH_OPTS "$src" "$dst"
}

# --- Lire la conf cluster ----------------------------------------------------
MASTER_IP=$(yq e '.nodes.master.ip' "$CLUSTER_CONFIG")
MASTER_USER=$(yq e '.nodes.master.user' "$CLUSTER_CONFIG")
readarray -t WORKERS_IPS   < <(yq e '.nodes.workers[].ip' "$CLUSTER_CONFIG")
readarray -t WORKERS_USERS < <(yq e '.nodes.workers[].user' "$CLUSTER_CONFIG")

MASTER="$MASTER_USER@$MASTER_IP"

# --- 1) Copier conf et stack sur le master ----------------------------------
scp_put "$CLUSTER_CONFIG" "$MASTER:~/"
scp_put "docker-compose.yml" "$MASTER:~/"

# --- 2) Préparer tous les nodes (yq + Docker) --------------------------------
prepare_node() {
  local ip="$1" user="$2"
  log "Préparation node $user@$ip"
  ssh_run "$user@$ip" '
    set -e
    if ! command -v yq >/dev/null 2>&1; then
      wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O yq
      chmod +x yq && sudo mv yq /usr/local/bin/yq
    fi
    if ! command -v docker >/dev/null 2>&1; then
      sudo apt update && sudo apt install -y ca-certificates curl gnupg
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      sudo apt update
      sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo systemctl enable docker
      sudo systemctl start docker
    fi
  '
}
prepare_node "$MASTER_IP" "$MASTER_USER"
for i in "${!WORKERS_IPS[@]}"; do
  prepare_node "${WORKERS_IPS[$i]}" "${WORKERS_USERS[$i]}"
done

# --- 3) Init Swarm sur master ------------------------------------------------
init_swarm() {
  log "Initialisation du Swarm (master=$MASTER_IP)"
  ssh_run "$MASTER" "
    if ! sudo docker info 2>/dev/null | grep -q 'Swarm: active'; then
      sudo docker swarm init --advertise-addr $MASTER_IP
    fi
  "
}
init_swarm

# --- 4) Join des workers -----------------------------------------------------
join_workers() {
  log "Join des workers"
  local token
  token=$(ssh_run "$MASTER" "sudo docker swarm join-token worker -q")
  for i in "${!WORKERS_IPS[@]}"; do
    local ip="${WORKERS_IPS[$i]}"
    local user="${WORKERS_USERS[$i]}"
    log " -> $user@$ip"
    ssh_run "$user@$ip" "sudo docker swarm join --token $token $MASTER_IP:2377" \
      || log "   (déjà joint ou échec non bloquant)"
  done
}
join_workers

# --- 5) Déploiement du stack -------------------------------------------------
deploy_stack() {
  log "Déploiement du stack 'littlepigs'"
  ssh_run "$MASTER" "sudo docker stack deploy -c ~/docker-compose.yml littlepigs"
}
deploy_stack

# --- 6) Post-déploiement: durcissement nginx / frontend ----------------------
post_hardening() {
  log "Post-déploiement: ajout tmpfs + désactivation read-only si besoin"

  ensure_tmpfs_mount() {
    local svc="$1" target="$2"
    # Ajoute un mount tmpfs; si déjà présent, Docker ignore le doublon
    ssh_run "$MASTER" "sudo docker service update --mount-add type=tmpfs,target=$target $svc" || true
  }

  disable_readonly() {
    local svc="$1"
    ssh_run "$MASTER" "sudo docker service update --read-only=false $svc" || true
  }

  tune_service() {
    local svc="$1"
    disable_readonly "$svc"
    ensure_tmpfs_mount "$svc" "/var/cache/nginx"
    ensure_tmpfs_mount "$svc" "/var/run"
  }

  # Services concernés (images basées sur nginx)
  tune_service "littlepigs_nginx"
  tune_service "littlepigs_frontend"

  log "État des services après durcissement :"
  ssh_run "$MASTER" "sudo docker service ls"
  ssh_run "$MASTER" "sudo docker service ps littlepigs_nginx --no-trunc | tail -n +1"
  ssh_run "$MASTER" "sudo docker service ps littlepigs_frontend --no-trunc | tail -n +1"
}
post_hardening

log "Deployment complete."
