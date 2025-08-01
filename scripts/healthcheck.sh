#!/bin/bash
set -e

CLUSTER_CONFIG="cluster_config.yml"
SSH_KEY="~/.ssh/id_ed25519_github"
logfile="$HOME/cluster_health.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$logfile"
}

MASTER_IP=$(yq e '.nodes.master.ip' $CLUSTER_CONFIG)
MASTER_USER=$(yq e '.nodes.master.user' $CLUSTER_CONFIG)
WORKERS_IPS=($(yq e '.nodes.workers[].ip' $CLUSTER_CONFIG))
WORKERS_USERS=($(yq e '.nodes.workers[].user' $CLUSTER_CONFIG))

log "===== ÉTAT DU CLUSTER SWARM ====="
ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "
  echo '[NODES SWARM]'; sudo docker node ls;
  echo '[SERVICES SWARM]'; sudo docker service ls;
  echo '[LITTLEPIGS_BACKEND TASKS]'; sudo docker service ps littlepigs_backend;
  echo '[CONTAINERS RUNNING]'; sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}';
  echo '[Espace disque]'; df -h /
" | tee -a "$logfile"

log "===== TEST HTTP NGINX SUR TOUS LES NODES ====="
for IP in "$MASTER_IP" "${WORKERS_IPS[@]}"; do
  echo -n "Test accès HTTP Nginx sur $IP:3000 ... " | tee -a "$logfile"
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$IP:3000 || true)
  echo "$CODE" | tee -a "$logfile"
  if [[ "$CODE" != "200" ]]; then
    echo "[WARNING] Nginx sur $IP:3000 ne répond pas en HTTP 200 (code retourné : $CODE)" | tee -a "$logfile"
  fi
done

log "===== TEST API BACKEND SUR MASTER ====="
API_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$MASTER_IP:5000/api/stats || true)
echo "Test API Backend sur $MASTER_IP:5000/api/stats ... $API_CODE" | tee -a "$logfile"
if [[ "$API_CODE" != "200" ]]; then
  echo "[WARNING] Backend API ($MASTER_IP:5000/api/stats) ne répond pas en HTTP 200 (code : $API_CODE)" | tee -a "$logfile"
fi

for i in "${!WORKERS_IPS[@]}"; do
  IP="${WORKERS_IPS[$i]}"
  USER="${WORKERS_USERS[$i]}"
  log "===== ÉTAT DU WORKER $USER ====="
  ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$USER@$IP" "
    echo '[CONTAINERS RUNNING]'; sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}';
    echo '[Espace disque]'; df -h /
  " | tee -a "$logfile"
done

log "===== LOGS DU BACKEND (5 dernières lignes) ====="
ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "
  sudo docker logs \$(sudo docker ps --filter name=backend --format '{{.Names}}' | head -1) | tail -n 5
" | tee -a "$logfile"

log "===== FIN CHECK ====="
