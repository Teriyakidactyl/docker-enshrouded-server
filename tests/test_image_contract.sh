#!/bin/bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="$REPO_ROOT/Dockerfile"
HOOK="$REPO_ROOT/scripts/container/hooks/pre-startup/30_enshrouded.sh"

grep -Fq 'STEAM_SERVER_APPID="2278520"' "$DOCKERFILE"
grep -Fq 'STEAM_PLATFORM_TYPE="windows"' "$DOCKERFILE"
grep -Fq 'APP_EXE="enshrouded_server.exe"' "$DOCKERFILE"
grep -Fq 'APP_STOP_SIGNAL="INT"' "$DOCKERFILE"

if grep -Eq '(^|[[:space:]])(wine|wine64|proton|box64|box86)([[:space:]]|$)' "$HOOK"; then
    echo 'Enshrouded hook must not own the compatibility launcher' >&2
    exit 1
fi

if grep -Eq '@sSteamCmdForcePlatformType|app_update[[:space:]]+2278520|steamcmd\.sh' "$HOOK"; then
    echo 'Enshrouded hook must not own SteamCMD updates' >&2
    exit 1
fi

echo 'Enshrouded shared-base contract test passed'
