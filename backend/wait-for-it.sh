#!/usr/bin/env bash
host=$(echo "$1" | cut -d: -f1)
port=$(echo "$1" | cut -d: -f2)
timeout=${2:-60}

echo "Waiting $timeout seconds for $host:$port..."

start=$(date +%s)
while :
do
  nc -z "$host" "$port" && echo "$host:$port is available" && exit 0
  now=$(date +%s)
  elapsed=$((now - start))
  if [ "$elapsed" -ge "$timeout" ]; then
    echo "Timeout after $timeout seconds waiting for $host:$port"
    exit 1
  fi
  sleep 3
done
