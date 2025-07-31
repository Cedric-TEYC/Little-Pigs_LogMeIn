#!/bin/bash
set -e

CLUSTER_CONFIG="cluster_config.yml"

MASTER_IP=$(yq e '.nodes.master.ip' $CLUSTER_CONFIG)
MASTER_USER=$(yq e '.nodes.master.user' $CLUSTER_CONFIG)

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

join_workers() {
  ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "
    WORKERS=\$(yq e '.nodes.workers[] | .ip + \" \" + .user' $CLUSTER_CONFIG)
    TOKEN=\$(sudo docker swarm join-token worker -q)
    for worker in \$WORKERS; do
      IP=\$(echo \$worker | cut -d' ' -f1)
      USER=\$(echo \$worker | cut -d' ' -f2)
      ssh -o StrictHostKeyChecking=no \$USER@\$IP \"sudo docker swarm join --token \$TOKEN $MASTER_IP:2377\" || echo \"Worker \$IP already joined or failed\"
    done
  "
}

deploy_stack() {
  scp -o StrictHostKeyChecking=no docker-compose.yml "$MASTER_USER@$MASTER_IP:~/"
  ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "sudo docker stack deploy -c ~/docker-compose.yml littlepigs"
}

echo "Starting cluster deployment..."

install_docker "$MASTER_IP" "$MASTER_USER"
init_swarm
join_workers
deploy_stack

echo "Deployment complete."
