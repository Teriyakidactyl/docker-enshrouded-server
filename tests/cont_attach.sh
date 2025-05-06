#!/bin/bash

# Start the Enshrouded container with an interactive shell (manual mode)

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

# Run the container interactively with a bash shell
echo "Starting Enshrouded container with interactive bash shell..."
docker run -it \
  --name ${CONTAINER_NAME} \
  ${IMAGE_NAME} \
  /bin/bash

# From here, you can manually start enshrouded_up.sh or inspect the environment
source /etc/environment
source $SCRIPTS/container/logging.sh