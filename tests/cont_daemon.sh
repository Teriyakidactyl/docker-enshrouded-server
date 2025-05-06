#!/bin/bash

# Start the Enshrouded server container in detached mode

# Container name
CONTAINER_NAME="Enshrouded-Server"

# Image name
IMAGE_NAME="ghcr.io/teriyakidactyl/docker-steamcmd-server:bookworm-20250407-slim_proton-9.26_dev"

# Stop and remove the container if it already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container ${CONTAINER_NAME} already exists. Stopping and removing it..."
  docker stop ${CONTAINER_NAME} >/dev/null 2>&1
  docker rm ${CONTAINER_NAME} >/dev/null 2>&1
fi

# Run the container detached
echo "Starting Enshrouded server container in detached mode..."
docker run -d \
  --name ${CONTAINER_NAME} \
  -p 15636:15636/udp \
  -p 15636:15636/tcp \
  -p 15637:15637/udp \
  -p 15637:15637/tcp \
  -e SERVER_NAME="Teriyakolypse" \
  -e SERVER_PLAYER_PASS="MySecretPassword" \
  -e SERVER_ADMIN_PASS="MySecretPasswordAdmin" \
  ${IMAGE_NAME}

# Optional: Attach to logs or monitor with btop
btop
