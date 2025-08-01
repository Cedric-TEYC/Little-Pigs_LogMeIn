#!/bin/bash
set -e

CLUSTER_CONFIG="cluster_config.yml"
SSH_KEY="~/.ssh/id_ed25519_github" # Utilise toujours cette clé

# Récupérer IP/user master + arrays pour workers depuis le YAML sur l'admin
MASTER_IP=$(yq e '.nodes.master.ip' $CLUSTER_CONFIG)
MASTER_USER=$(yq e '.nodes.master.user' $CLUSTER_CONFIG)
WORKERS_IPS=($(yq e '.nodes.workers[].ip' $CLUSTER_CONFIG))
WORKERS_USERS=($(yq e '.nodes.workers[].user' $CLUSTER_CONFIG))

# 1. Copier cluster_config.yml et docker-compose.yml de l'admin vers le master
scp -i $SSH_KEY -o StrictHostKeyChecking=no "$CLUSTER_CONFIG" "$MASTER_USER@$MASTER_IP:~/"
scp -i $SSH_KEY -o StrictHostKeyChecking=no docker-compose.yml "$MASTER_USER@$MASTER_IP:~/"

# 2. Préparer tous les nodes (yq + Docker install)
prepare_node() {
  local ip=$1
  local user=$2
  ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$user@$ip" "
    if ! command -v yq &> /dev/null; then
      wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O yq
      chmod +x yq
      sudo mv yq /usr/local/bin/yq
    fi
    if ! command -v docker &> /dev/null; then
      sudo apt update && sudo apt install -y ca-certificates curl gnupg
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt update
      sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo systemctl enable docker
      sudo systemctl start docker
    fi
  "
}

prepare_node "$MASTER_IP" "$MASTER_USER"
for i in "${!WORKERS_IPS[@]}"; do
  prepare_node "${WORKERS_IPS[$i]}" "${WORKERS_USERS[$i]}"
done

# 3. Init swarm sur master
init_swarm() {
  ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "
    if ! sudo docker info | grep 'Swarm: active' &> /dev/null; then
      sudo docker swarm init --advertise-addr $MASTER_IP
    fi
  "
}

# 4. Join des workers (depuis admin-auto, plus jamais de nested SSH !)
join_workers() {
  TOKEN=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "sudo docker swarm join-token worker -q")
  for i in "${!WORKERS_IPS[@]}"; do
    IP="${WORKERS_IPS[$i]}"
    USER="${WORKERS_USERS[$i]}"
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$USER@$IP" "sudo docker swarm join --token $TOKEN $MASTER_IP:2377" || echo "Worker $IP already joined or failed"
  done
}

# 5. Déploiement du stack sur le master
deploy_stack() {
  ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "sudo docker stack deploy -c ~/docker-compose.yml littlepigs"
}

echo "Starting cluster deployment..."
init_swarm
join_workers
deploy_stack
echo "Deployment complete."
