#!/bin/bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/scripts/container/hooks/pre-startup/30_enshrouded.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

log() { :; }

FRESH_ROOT="$(mktemp -d)"
export APP_FILES="$FRESH_ROOT/app"
export WORLD_FILES="$FRESH_ROOT/world"
mkdir -p "$APP_FILES"
printf 'fake exe\n' > "$APP_FILES/enshrouded_server.exe"
unset ENSHROUDED_CONFIG_PATH ENSHROUDED_SAVE_PATH ENSHROUDED_LOG_PATH
unset SERVER_ROLE_0_PASSWORD SERVER_ROLE_1_PASSWORD SERVER_ROLE_2_PASSWORD
unset SERVER_PLAYER_PASS SERVER_ADMIN_PASS SERVER_PASSWORD
source "$HOOK"
FRESH_CONFIG="$WORLD_FILES/enshrouded_server.json"
jq -e '
    (.userGroups | length) == 3
    and (.userGroups[0].password | length) >= 24
    and (.userGroups[1].password | length) >= 24
    and (.userGroups[2].password | length) >= 24
' "$FRESH_CONFIG" >/dev/null
rm -rf "$FRESH_ROOT"

export APP_FILES="$TMP_ROOT/app"
export WORLD_FILES="$TMP_ROOT/world"
unset ENSHROUDED_CONFIG_PATH ENSHROUDED_SAVE_PATH ENSHROUDED_LOG_PATH
mkdir -p "$APP_FILES"
printf 'fake exe\n' > "$APP_FILES/enshrouded_server.exe"

export SERVER_NAME='My Enshrouded Server'
export SERVER_IP='0.0.0.0'
export SERVER_QUERY_PORT='15637'
export SERVER_SLOT_COUNT='12'
export SERVER_VOICE_CHAT_MODE='Global'
export SERVER_ENABLE_VOICE_CHAT='true'
export SERVER_ENABLE_TEXT_CHAT='false'
export SERVER_GAME_SETTINGS_PRESET='Custom'
export SERVER_ROLE_0_NAME='Operators'
export SERVER_ROLE_0_PASSWORD='admin secret'
export SERVER_ROLE_0_CAN_KICK_BAN='true'
export SERVER_ROLE_0_RESERVED_SLOTS='2'
export SERVER_ROLE_1_NAME='Builders'
export SERVER_ROLE_1_PASSWORD='friend secret'
export SERVER_ROLE_1_CAN_ACCESS_INVENTORIES='true'
export SERVER_ROLE_1_CAN_EDIT_BASE='true'
export SERVER_GS_PLAYER_HEALTH_FACTOR='1.25'
export SERVER_GS_ENABLE_STARVING_DEBUFF='false'
unset SERVER_PLAYER_PASS SERVER_ADMIN_PASS SERVER_PASSWORD

source "$HOOK"

CONFIG="$WORLD_FILES/enshrouded_server.json"
test -L "$APP_FILES/enshrouded_server.json"
test -L "$APP_FILES/savegame"
test -L "$APP_FILES/logs"
test "$(realpath -m "$APP_FILES/enshrouded_server.json")" = "$(realpath -m "$CONFIG")"
test "$(stat -c '%a' "$CONFIG")" = '600'

jq -e '
    .name == "My Enshrouded Server"
    and .saveDirectory == "./savegame"
    and .logDirectory == "./logs"
    and .queryPort == 15637
    and .slotCount == 12
    and .voiceChatMode == "Global"
    and .enableVoiceChat == true
    and .enableTextChat == false
    and .gameSettingsPreset == "Custom"
    and .userGroups[0].name == "Operators"
    and .userGroups[0].password == "admin secret"
    and .userGroups[0].canKickBan == true
    and .userGroups[0].reservedSlots == 2
    and .userGroups[1].name == "Builders"
    and .userGroups[1].password == "friend secret"
    and .userGroups[1].canAccessInventories == true
    and .userGroups[1].canEditBase == true
    and .gameSettings.playerHealthFactor == 1.25
    and .gameSettings.enableStarvingDebuff == false
' "$CONFIG" >/dev/null

tmp_json="$(mktemp)"
jq '.futureNativeField = {enabled: true}' "$CONFIG" > "$tmp_json"
mv "$tmp_json" "$CONFIG"
chmod 0600 "$CONFIG"
source "$HOOK"
jq -e '.futureNativeField.enabled == true' "$CONFIG" >/dev/null

inode_before="$(stat -c '%i' "$CONFIG")"
source "$HOOK"
inode_after="$(stat -c '%i' "$CONFIG")"
test "$inode_before" = "$inode_after"

rm "$APP_FILES/savegame"
mkdir -p "$APP_FILES/savegame"
printf 'from-app\n' > "$APP_FILES/savegame/new-save"
printf 'persistent\n' > "$WORLD_FILES/savegame/existing-save"
source "$HOOK"
test -L "$APP_FILES/savegame"
grep -Fqx 'from-app' "$WORLD_FILES/savegame/new-save"
grep -Fqx 'persistent' "$WORLD_FILES/savegame/existing-save"

LEGACY_ROOT="$(mktemp -d)"
export APP_FILES="$LEGACY_ROOT/app"
export WORLD_FILES="$LEGACY_ROOT/world"
unset ENSHROUDED_CONFIG_PATH ENSHROUDED_SAVE_PATH ENSHROUDED_LOG_PATH
mkdir -p "$APP_FILES" "$WORLD_FILES"
printf 'fake exe\n' > "$APP_FILES/enshrouded_server.exe"
cat > "$APP_FILES/enshrouded_server.json" <<'JSON'
{
  "password": "old-password",
  "futureField": 42
}
JSON
unset SERVER_ROLE_0_NAME SERVER_ROLE_0_PASSWORD SERVER_ROLE_0_CAN_KICK_BAN SERVER_ROLE_0_RESERVED_SLOTS
unset SERVER_ROLE_1_NAME SERVER_ROLE_1_PASSWORD SERVER_ROLE_1_CAN_ACCESS_INVENTORIES SERVER_ROLE_1_CAN_EDIT_BASE
unset SERVER_GS_PLAYER_HEALTH_FACTOR SERVER_GS_ENABLE_STARVING_DEBUFF
export SERVER_NAME='Legacy Server'
export SERVER_SLOT_COUNT='16'
export SERVER_VOICE_CHAT_MODE='Proximity'
export SERVER_ENABLE_VOICE_CHAT='false'
export SERVER_ENABLE_TEXT_CHAT='false'
export SERVER_GAME_SETTINGS_PRESET='Default'
source "$HOOK"
LEGACY_CONFIG="$WORLD_FILES/enshrouded_server.json"
jq -e '
    .password == ""
    and .userGroups[0].name == "Default"
    and .userGroups[0].password == "old-password"
    and .userGroups[0].canAccessInventories == true
    and .futureField == 42
' "$LEGACY_CONFIG" >/dev/null
rm -rf "$LEGACY_ROOT"

ALIAS_ROOT="$(mktemp -d)"
export APP_FILES="$ALIAS_ROOT/app"
export WORLD_FILES="$ALIAS_ROOT/world"
unset ENSHROUDED_CONFIG_PATH ENSHROUDED_SAVE_PATH ENSHROUDED_LOG_PATH
mkdir -p "$APP_FILES"
printf 'fake exe\n' > "$APP_FILES/enshrouded_server.exe"
export SERVER_ADMIN_PASS='legacy-admin'
export SERVER_PLAYER_PASS='legacy-player'
source "$HOOK"
ALIAS_CONFIG="$WORLD_FILES/enshrouded_server.json"
jq -e '
    .userGroups[0].password == "legacy-admin"
    and .userGroups[1].password == "legacy-player"
' "$ALIAS_CONFIG" >/dev/null
rm -rf "$ALIAS_ROOT"

expect_hook_failure() {
    local description="$1"
    shift
    local status

    set +e
    (
        "$@"
        source "$HOOK"
    )
    status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        echo "$description unexpectedly passed validation" >&2
        exit 1
    fi
}

FAIL_ROOT="$(mktemp -d)"
export APP_FILES="$FAIL_ROOT/app"
export WORLD_FILES="$FAIL_ROOT/world"
unset ENSHROUDED_CONFIG_PATH ENSHROUDED_SAVE_PATH ENSHROUDED_LOG_PATH
mkdir -p "$APP_FILES"
printf 'fake exe\n' > "$APP_FILES/enshrouded_server.exe"
unset SERVER_ADMIN_PASS SERVER_PLAYER_PASS SERVER_PASSWORD
set_bad_slots() { export SERVER_SLOT_COUNT=17; }
set_bad_boolean() { export SERVER_ENABLE_TEXT_CHAT=maybe; }
set_bad_role() { export SERVER_ROLE_0_CAN_KICK_BAN=maybe; }
expect_hook_failure 'SERVER_SLOT_COUNT=17' set_bad_slots
export SERVER_SLOT_COUNT=16
expect_hook_failure 'SERVER_ENABLE_TEXT_CHAT=maybe' set_bad_boolean
export SERVER_ENABLE_TEXT_CHAT=false
expect_hook_failure 'invalid role boolean' set_bad_role
rm -rf "$FAIL_ROOT"

echo 'Enshrouded hook contract test passed'
