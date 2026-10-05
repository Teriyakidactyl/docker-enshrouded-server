# Enshrouded dedicated server - derivative of docker-steamcmd-server.
# The default base is the cross-architecture Wine alias so a plain local build
# works on amd64 and arm64. Published amd64 images use the supported Proton
# alias; published arm64 images use Wine + the base-owned Box64 adapter.
ARG BASE_IMAGE=ghcr.io/teriyakidactyl/docker-steamcmd-server
ARG BASE_TAG=trixie_wine-staging
FROM ${BASE_IMAGE}:${BASE_TAG}

ARG BASE_IMAGE
ARG BASE_TAG

LABEL org.opencontainers.image.title="Enshrouded Server" \
      org.opencontainers.image.description="Enshrouded dedicated server based on docker-steamcmd-server" \
      org.opencontainers.image.vendor="TeriyakiDactyl" \
      org.opencontainers.image.source="https://github.com/Teriyakidactyl/docker-enshrouded-server" \
      org.opencontainers.image.base.name="${BASE_IMAGE}:${BASE_TAG}"

ENV APP_NAME="enshrouded" \
    APP_EXE="enshrouded_server.exe" \
    APP_PROCESS_NAME="enshrouded_server.exe" \
    APP_LOG_NAME="enshrouded-server" \
    APP_STOP_SIGNAL="INT" \
    SHUTDOWN_TIMEOUT="90" \
    STEAM_SERVER_APPID="2278520" \
    STEAM_PLATFORM_TYPE="windows" \
    SERVER_NAME="Enshrouded Server" \
    SERVER_IP="0.0.0.0" \
    SERVER_QUERY_PORT="15637" \
    SERVER_SLOT_COUNT="16" \
    SERVER_VOICE_CHAT_MODE="Proximity" \
    SERVER_ENABLE_VOICE_CHAT="false" \
    SERVER_ENABLE_TEXT_CHAT="false" \
    SERVER_GAME_SETTINGS_PRESET="Default" \
    SERVER_PLAYER_PASS="" \
    SERVER_ADMIN_PASS="" \
    SERVER_PASSWORD=""

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends jq; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p "${HOOK_DIRECTORIES}/pre-startup" /usr/local/share/enshrouded

COPY scripts/container/enshrouded_server.default.json /usr/local/share/enshrouded/enshrouded_server.default.json
COPY scripts/container/hooks/pre-startup/30_enshrouded.sh ${HOOK_DIRECTORIES}/pre-startup/30_enshrouded.sh

RUN chown root:root \
        /usr/local/share/enshrouded/enshrouded_server.default.json \
        "${HOOK_DIRECTORIES}/pre-startup/30_enshrouded.sh" \
    && chmod 0644 /usr/local/share/enshrouded/enshrouded_server.default.json \
    && chmod 0755 "${HOOK_DIRECTORIES}/pre-startup/30_enshrouded.sh"

USER ${CONTAINER_USER}
WORKDIR /app

EXPOSE 15637/udp
