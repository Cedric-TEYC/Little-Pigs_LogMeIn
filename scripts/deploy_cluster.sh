#!/bin/bash
set -e

# Récupération des variables d'environnement
MASTER_IP="${MASTER_IP}"
MASTER_USER="${SSH_USER}"

# Parsing des IPs workers (séparées par des virgules)
IFS=',' read -r -a WORKERS_IPS <<< "$WORKER_IPS"

# On considère que le SSH_USER est le même pour tous les workers
WORKERS_USERS=()
for ip in "${WORKERS_IPS[@]}"; do
  WORKERS_USERS+=("$SSH_USER")
done

install_docker() {
  local ip=$1
  local user=$2
  ssh -o StrictHostKeyChecking=no "$user@$ip" "
    if ! command -v docker &> /dev/null; then
      echo \"Installing Docker on $ip...\"
      sudo apt update && sudo apt install -y ca-certificates curl gnupg
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt update
      sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo systemctl enable docker
      sudo systemctl start docker
    else
      echo \"Docker already installed on $ip\"
    fi
  "
}

init_swarm() {
  ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "
    if ! sudo docker info | grep 'Swarm: active' &> /dev/null; then
      sudo docker swarm init --advertise-addr $MASTER_IP
      echo 'Swarm initialized on Master'
    else
      echo 'Swarm already initialized'
    fi
  "
}

get_worker_token() {
  ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "sudo docker swarm join-token worker -q"
}

join_workers() {
  local token=$1
  for i in "${!WORKERS_IPS[@]}"; do
    ssh -o StrictHostKeyChecking=no "${WORKERS_USERS[$i]}@${WORKERS_IPS[$i]}" "
      if ! sudo docker info | grep 'Swarm: active' &> /dev/null; then
        sudo docker swarm join --token $token $MASTER_IP:2377
        echo \"Worker ${WORKERS_IPS[$i]} joined the cluster\"
      else
        echo \"Worker ${WORKERS_IPS[$i]} already in a Swarm\"
      fi
    "
  done
}

deploy_stack() {
  scp -o StrictHostKeyChecking=no docker-compose.yml "$MASTER_USER@$MASTER_IP:~/"
  ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "sudo docker stack deploy -c ~/docker-compose.yml littlepigs"
}

echo "Starting cluster deployment..."

for i in "${!WORKERS_IPS[@]}"; do
  install_docker "${WORKERS_IPS[$i]}" "${WORKERS_USERS[$i]}"
done

install_docker "$MASTER_IP" "$MASTER_USER"
init_swarm
TOKEN=$(get_worker_token)
join_workers "$TOKEN"
deploy_stack

echo "Deployment complete."
