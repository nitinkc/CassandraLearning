#!/usr/bin/env bash
set -euo pipefail

# Helper to start the 2-node Cassandra demo defined in docker/docker-compose.yml
# Usage: ./scripts/start-2node.sh

COMPOSE_FILE="docker/docker-compose.yml"
TIMEOUT_SECONDS=300
SLEEP_INTERVAL=5

echo "Using compose file: $COMPOSE_FILE"

# start services
docker compose -f "$COMPOSE_FILE" up -d

# wait function that executes a simple cqlsh query inside the container
wait_for_node() {
  local svc="$1"
  local elapsed=0
  echo "Waiting for $svc to accept CQL connections... (timeout=${TIMEOUT_SECONDS}s)"
  while true; do
    if docker compose -f "$COMPOSE_FILE" exec -T "$svc" cqlsh -e "SELECT now() FROM system.local;" >/dev/null 2>&1; then
      echo "$svc is healthy"
      break
    fi
    sleep $SLEEP_INTERVAL
    elapsed=$((elapsed + SLEEP_INTERVAL))
    if [ $elapsed -ge $TIMEOUT_SECONDS ]; then
      echo "Timeout waiting for $svc (waited ${elapsed}s)"
      docker compose -f "$COMPOSE_FILE" ps
      exit 1
    fi
  done
}

# wait for both nodes
wait_for_node cassandra
wait_for_node cassandra2

# run init CQL (init.cql is expected to be mounted into /init/init.cql in the cassandra service)
echo "Running init.cql on cassandra..."
docker compose -f "$COMPOSE_FILE" exec -T cassandra cqlsh -f /init/init.cql || {
  echo "Initial CQL execution failed; see container logs for details"
  docker compose -f "$COMPOSE_FILE" logs cassandra | tail -n 200
  exit 1
}

# run a quick cluster sanity check: list system.peers from node1
echo "Checking cluster topology from cassandra node..."

docker compose -f "$COMPOSE_FILE" exec -T cassandra cqlsh -e "SELECT peer, rpc_address, host_id, data_center, rack FROM system.peers;" || {
  echo "Failed to query system.peers; showing system.local info as a fallback"
  docker compose -f "$COMPOSE_FILE" exec -T cassandra cqlsh -e "SELECT cluster_name, data_center, rack, host_id, rpc_address FROM system.local;"
}


echo "Cluster started and initialized."

echo "You can connect with: cqlsh 127.0.0.1 9042 (node1) or cqlsh 127.0.0.1 9043 (node2)"

