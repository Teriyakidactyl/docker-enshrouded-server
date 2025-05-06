# Set ARG for building
ARG BASE_TAG=trixie-20250407-slim_proton-9.26
# Use the base SteamCMD server image
FROM ghcr.io/teriyakidactyl/docker-steamcmd-server:${BASE_TAG}

# Build ARGs for metadata
ARG SOURCE_COMMIT
ARG BUILD_DATE
ARG BRANCH_NAME

# Labels
LABEL org.opencontainers.image.title="Enshrouded Server" \
      org.opencontainers.image.description="Docker image for Enshrouded dedicated server" \
      org.opencontainers.image.vendor="TeriyakiDactyl" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}" \
      com.example.git.branch="${BRANCH_NAME}"

# Set game-specific environment variables
ENV \
    # Primary Variables
    APP_NAME="enshrouded" \
    APP_EXE="enshrouded_server.exe" \
    APP_ARGS="-log" \
    \
    # SteamCMD
    STEAM_SERVER_APPID="2278520" \
    STEAM_CLIENT_APPID="1203620" \
    STEAM_PLATFORM_TYPE="windows" \
    \
    # App Variables
    SERVER_PLAYER_PASS="MySecretPassword" \
    SERVER_ADMIN_PASS="MySecretPasswordAdmin" \
    SERVER_NAME="Teriyakolypse" \
    SERVER_MAX_PLAYERS="16" \
    SERVER_GAME_PORT="15636" \
    SERVER_QUERY_PORT="15637" \
    \
    # Log settings
    LOG_FILTER_SKIP=""

# Create additional directories and links specific to Enshrouded
# RUN mkdir -p $WORLD_FILES/savegame \
#              $WORLD_FILES/logs \
#              $WORLD_FILES/config \
#              $APP_FILES && \
#     ln -sf "$WORLD_FILES/savegame" "$APP_FILES/savegame" && \
#     ln -sf "$WORLD_FILES/logs" "$APP_FILES/logs" && \
#     ln -sf "$WORLD_FILES/config" "$APP_FILES/config" && \
#     touch "$LOGS/enshrouded_server.log" && \
#     ln -sf "$LOGS/enshrouded_server.log" "$WORLD_FILES/logs/enshrouded_server.log" && \
#     chown -R $APP_USER:$APP_USER $WORLD_FILES $APP_FILES $LOGS

# Copy server scripts
COPY --chown=${APP_USER}:${APP_USER} scripts ${SCRIPTS}

# Expose necessary ports
EXPOSE \
    # Game port (TCP/UDP)
    15636/tcp \
    15636/udp \
    # Query port (TCP/UDP)
    15637/tcp \
    15637/udp
