#!/bin/bash

set -Eeuo pipefail

HOOK_NAME="30_enshrouded.sh"
ENSHROUDED_CONFIG_PATH="${ENSHROUDED_CONFIG_PATH:-$WORLD_FILES/enshrouded_server.json}"
ENSHROUDED_SAVE_PATH="${ENSHROUDED_SAVE_PATH:-$WORLD_FILES/savegame}"
ENSHROUDED_LOG_PATH="${ENSHROUDED_LOG_PATH:-$WORLD_FILES/logs}"
ENSHROUDED_CONFIG_LINK="$APP_FILES/enshrouded_server.json"
ENSHROUDED_SAVE_LINK="$APP_FILES/savegame"
ENSHROUDED_LOG_LINK="$APP_FILES/logs"

fail() {
    log "ERROR: $*" "$HOOK_NAME"
    return 1
}

warn() {
    log "WARNING: $*" "$HOOK_NAME"
}

validate_integer_range() {
    local name="$1"
    local value="$2"
    local min="$3"
    local max="$4"

    if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < min || value > max )); then
        fail "$name must be an integer from $min through $max; got '$value'"
        return 1
    fi
}

validate_boolean() {
    local name="$1"
    local value="${2,,}"

    case "$value" in
        true|false) ;;
        *)
            fail "$name must be true or false; got '$2'"
            return 1
            ;;
    esac
}

validate_choice() {
    local name="$1"
    local value="$2"
    shift 2
    local candidate

    for candidate in "$@"; do
        if [ "$value" = "$candidate" ]; then
            return 0
        fi
    done

    fail "$name must be one of: $*; got '$value'"
    return 1
}

validate_single_line() {
    local name="$1"
    local value="$2"

    if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
        fail "$name may not contain newlines"
        return 1
    fi
}

absolute_path_required() {
    local name="$1"
    local value="$2"

    case "$value" in
        /*) ;;
        *)
            fail "$name must be an absolute path; got '$value'"
            return 1
            ;;
    esac
}

random_password() {
    od -An -N18 -tx1 /dev/urandom | tr -d ' \n'
}

persist_directory() {
    local source_path="$1"
    local target_path="$2"
    local current_target current_target_path

    mkdir -p "$(dirname "$source_path")" "$target_path"

    if [ -L "$source_path" ]; then
        current_target="$(readlink "$source_path")"
        if [[ "$current_target" = /* ]]; then
            current_target_path="$(realpath -m "$current_target")"
        else
            current_target_path="$(realpath -m "$(dirname "$source_path")/$current_target")"
        fi

        if [ "$current_target_path" != "$(realpath -m "$target_path")" ]; then
            fail "$source_path points to $current_target; expected $target_path"
            return 1
        fi
        return 0
    fi

    if [ -e "$source_path" ]; then
        if [ ! -d "$source_path" ]; then
            fail "$source_path exists but is not a directory"
            return 1
        fi

        cp -a -n "$source_path/." "$target_path/"
        rm -rf "$source_path"
    fi

    ln -s "$target_path" "$source_path"
}

persist_file() {
    local source_path="$1"
    local target_path="$2"
    local current_target current_target_path

    mkdir -p "$(dirname "$source_path")" "$(dirname "$target_path")"

    if [ -L "$source_path" ]; then
        current_target="$(readlink "$source_path")"
        if [[ "$current_target" = /* ]]; then
            current_target_path="$(realpath -m "$current_target")"
        else
            current_target_path="$(realpath -m "$(dirname "$source_path")/$current_target")"
        fi

        if [ "$current_target_path" != "$(realpath -m "$target_path")" ]; then
            fail "$source_path points to $current_target; expected $target_path"
            return 1
        fi
        return 0
    fi

    if [ -e "$source_path" ]; then
        if [ ! -f "$source_path" ]; then
            fail "$source_path exists but is not a regular file"
            return 1
        fi

        if [ ! -e "$target_path" ]; then
            mv "$source_path" "$target_path"
            log "Adopted existing Enshrouded configuration into $target_path" "$HOOK_NAME"
        else
            rm -f "$source_path"
            warn "Persistent configuration at $target_path won over an install-volume copy"
        fi
    fi

    ln -s "$target_path" "$source_path"
}

create_initial_config() {
    local admin_password friend_password guest_password tmp

    admin_password="$(random_password)"
    friend_password="$(random_password)"
    guest_password="$(random_password)"
    tmp="$(mktemp "${ENSHROUDED_CONFIG_PATH}.initial.XXXXXX")"

    jq -n         --arg admin_password "$admin_password"         --arg friend_password "$friend_password"         --arg guest_password "$guest_password"         '{
            name: "Enshrouded Server",
            saveDirectory: "./savegame",
            logDirectory: "./logs",
            ip: "0.0.0.0",
            queryPort: 15637,
            slotCount: 16,
            voiceChatMode: "Proximity",
            enableVoiceChat: false,
            enableTextChat: false,
            gameSettingsPreset: "Default",
            userGroups: [
                {
                    name: "Admin",
                    password: $admin_password,
                    canKickBan: true,
                    canAccessInventories: true,
                    canEditBase: true,
                    canExtendBase: true,
                    reservedSlots: 1
                },
                {
                    name: "Friend",
                    password: $friend_password,
                    canKickBan: false,
                    canAccessInventories: true,
                    canEditBase: true,
                    canExtendBase: true,
                    reservedSlots: 3
                },
                {
                    name: "Guest",
                    password: $guest_password,
                    canKickBan: false,
                    canAccessInventories: false,
                    canEditBase: false,
                    canExtendBase: false,
                    reservedSlots: 0
                }
            ]
        }' > "$tmp"

    install -m 0600 "$tmp" "$ENSHROUDED_CONFIG_PATH"
    rm -f "$tmp"
    log "Created initial Enshrouded configuration with randomized role passwords; inspect $ENSHROUDED_CONFIG_PATH to retrieve or replace them" "$HOOK_NAME"
}

jq_apply() {
    local candidate="$1"
    shift
    local next

    next="$(mktemp "${candidate}.next.XXXXXX")"
    if ! jq "$@" "$candidate" > "$next"; then
        rm -f "$next"
        fail "failed to reconcile Enshrouded JSON configuration"
        return 1
    fi
    mv "$next" "$candidate"
}

ensure_role_index() {
    local candidate="$1"
    local index="$2"
    local role_password

    while (( $(jq '.userGroups | length' "$candidate") <= index )); do
        role_password="$(random_password)"
        jq_apply "$candidate"             --arg password "$role_password"             '.userGroups += [{
                name: "Custom",
                password: $password,
                canKickBan: false,
                canAccessInventories: false,
                canEditBase: false,
                canExtendBase: false,
                reservedSlots: 0
            }]'
    done
}

migrate_legacy_password() {
    local candidate="$1"
    local legacy_password group_count

    legacy_password="$(jq -r '.password // empty' "$candidate")"
    group_count="$(jq '(.userGroups // []) | length' "$candidate")"

    if [ -n "$legacy_password" ] && [ "$group_count" -eq 0 ]; then
        jq_apply "$candidate"             --arg password "$legacy_password"             '.userGroups = [{
                name: "Default",
                password: $password,
                canKickBan: false,
                canAccessInventories: true,
                canEditBase: true,
                canExtendBase: true,
                reservedSlots: 0
            }] | .password = ""'
        log "Migrated deprecated top-level Enshrouded password into a Default user group" "$HOOK_NAME"
    fi
}

role_env_present() {
    compgen -A variable | grep -Eq '^SERVER_ROLE_[0-9]+_'
}

role_password_env_present() {
    local index="$1"
    local variable="SERVER_ROLE_${index}_PASSWORD"
    [ -n "${!variable+x}" ]
}

apply_legacy_password_aliases() {
    local candidate="$1"

    if [ -n "${SERVER_ADMIN_PASS:-}" ] && ! role_password_env_present 0; then
        warn "SERVER_ADMIN_PASS is deprecated; mapping it to SERVER_ROLE_0_PASSWORD"
        ensure_role_index "$candidate" 0
        jq_apply "$candidate" --arg password "$SERVER_ADMIN_PASS" '.userGroups[0].password = $password'
    fi

    if [ -n "${SERVER_PLAYER_PASS:-${SERVER_PASSWORD:-}}" ] && ! role_password_env_present 1; then
        warn "SERVER_PLAYER_PASS/SERVER_PASSWORD is deprecated; mapping it to SERVER_ROLE_1_PASSWORD"
        ensure_role_index "$candidate" 1
        jq_apply "$candidate" --arg password "${SERVER_PLAYER_PASS:-${SERVER_PASSWORD:-}}" '.userGroups[1].password = $password'
    fi
}

apply_role_environment() {
    local candidate="$1"
    local variable index field value

    while IFS= read -r variable; do
        index="${variable#SERVER_ROLE_}"
        index="${index%%_*}"
        field="${variable#SERVER_ROLE_${index}_}"
        value="${!variable}"

        validate_integer_range "role index" "$index" 0 63
        ensure_role_index "$candidate" "$index"

        case "$field" in
            NAME)
                validate_single_line "$variable" "$value"
                jq_apply "$candidate" --argjson index "$index" --arg value "$value" '.userGroups[$index].name = $value'
                ;;
            PASSWORD)
                validate_single_line "$variable" "$value"
                jq_apply "$candidate" --argjson index "$index" --arg value "$value" '.userGroups[$index].password = $value'
                ;;
            CAN_KICK_BAN)
                validate_boolean "$variable" "$value"
                jq_apply "$candidate" --argjson index "$index" --argjson value "${value,,}" '.userGroups[$index].canKickBan = $value'
                ;;
            CAN_ACCESS_INVENTORIES)
                validate_boolean "$variable" "$value"
                jq_apply "$candidate" --argjson index "$index" --argjson value "${value,,}" '.userGroups[$index].canAccessInventories = $value'
                ;;
            CAN_EDIT_WORLD)
                validate_boolean "$variable" "$value"
                jq_apply "$candidate" --argjson index "$index" --argjson value "${value,,}" '.userGroups[$index].canEditWorld = $value'
                ;;
            CAN_EDIT_BASE)
                validate_boolean "$variable" "$value"
                jq_apply "$candidate" --argjson index "$index" --argjson value "${value,,}" '.userGroups[$index].canEditBase = $value'
                ;;
            CAN_EXTEND_BASE)
                validate_boolean "$variable" "$value"
                jq_apply "$candidate" --argjson index "$index" --argjson value "${value,,}" '.userGroups[$index].canExtendBase = $value'
                ;;
            RESERVED_SLOTS)
                validate_integer_range "$variable" "$value" 0 16
                jq_apply "$candidate" --argjson index "$index" --argjson value "$value" '.userGroups[$index].reservedSlots = $value'
                ;;
            *)
                fail "unsupported Enshrouded role variable: $variable"
                return 1
                ;;
        esac
    done < <(compgen -A variable | grep -E '^SERVER_ROLE_[0-9]+_' | sort -V || true)
}

camel_case_game_setting() {
    local suffix="$1"
    awk -v input="$suffix" 'BEGIN {
        n = split(tolower(input), parts, "_")
        output = parts[1]
        for (i = 2; i <= n; i++) {
            output = output toupper(substr(parts[i], 1, 1)) substr(parts[i], 2)
        }
        print output
    }'
}

apply_game_settings_environment() {
    local candidate="$1"
    local variable suffix key value

    while IFS= read -r variable; do
        suffix="${variable#SERVER_GS_}"
        value="${!variable}"
        [ -n "$value" ] || continue

        if [ "$suffix" = "PRESET" ]; then
            validate_choice "$variable" "$value" Default Relaxed Hard Survival Custom
            jq_apply "$candidate" --arg value "$value" '.gameSettingsPreset = $value'
            continue
        fi

        key="$(camel_case_game_setting "$suffix")"
        if [[ "$value" == "true" || "$value" == "false" ]]; then
            jq_apply "$candidate" --arg key "$key" --argjson value "$value" '.gameSettings = (.gameSettings // {}) | .gameSettings[$key] = $value'
        elif [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
            jq_apply "$candidate" --arg key "$key" --argjson value "$value" '.gameSettings = (.gameSettings // {}) | .gameSettings[$key] = $value'
        else
            validate_single_line "$variable" "$value"
            jq_apply "$candidate" --arg key "$key" --arg value "$value" '.gameSettings = (.gameSettings // {}) | .gameSettings[$key] = $value'
        fi
    done < <(compgen -A variable | grep -E '^SERVER_GS_' | sort || true)
}

reconcile_config() {
    local candidate existing_mode
    local server_name="${SERVER_NAME:-Enshrouded Server}"
    local server_ip="${SERVER_IP:-0.0.0.0}"
    local query_port="${SERVER_QUERY_PORT:-15637}"
    local slot_count="${SERVER_SLOT_COUNT:-16}"
    local voice_mode="${SERVER_VOICE_CHAT_MODE:-Proximity}"
    local enable_voice="${SERVER_ENABLE_VOICE_CHAT:-false}"
    local enable_text="${SERVER_ENABLE_TEXT_CHAT:-false}"
    local settings_preset="${SERVER_GAME_SETTINGS_PRESET:-Default}"

    validate_single_line SERVER_NAME "$server_name"
    validate_single_line SERVER_IP "$server_ip"
    validate_integer_range SERVER_QUERY_PORT "$query_port" 1 65535
    validate_integer_range SERVER_SLOT_COUNT "$slot_count" 1 16
    validate_choice SERVER_VOICE_CHAT_MODE "$voice_mode" Proximity Global
    validate_boolean SERVER_ENABLE_VOICE_CHAT "$enable_voice"
    validate_boolean SERVER_ENABLE_TEXT_CHAT "$enable_text"
    validate_choice SERVER_GAME_SETTINGS_PRESET "$settings_preset" Default Relaxed Hard Survival Custom

    if ! jq -e 'type == "object"' "$ENSHROUDED_CONFIG_PATH" >/dev/null; then
        fail "$ENSHROUDED_CONFIG_PATH is not a valid JSON object"
        return 1
    fi

    candidate="$(mktemp "${ENSHROUDED_CONFIG_PATH}.candidate.XXXXXX")"
    cp "$ENSHROUDED_CONFIG_PATH" "$candidate"

    jq_apply "$candidate"         --arg name "$server_name"         --arg ip "$server_ip"         --argjson query_port "$query_port"         --argjson slot_count "$slot_count"         --arg voice_mode "$voice_mode"         --argjson enable_voice "${enable_voice,,}"         --argjson enable_text "${enable_text,,}"         --arg preset "$settings_preset"         '.name = $name
         | .saveDirectory = "./savegame"
         | .logDirectory = "./logs"
         | .ip = $ip
         | .queryPort = $query_port
         | .slotCount = $slot_count
         | .voiceChatMode = $voice_mode
         | .enableVoiceChat = $enable_voice
         | .enableTextChat = $enable_text
         | .gameSettingsPreset = $preset'

    migrate_legacy_password "$candidate"
    apply_legacy_password_aliases "$candidate"
    if role_env_present; then
        apply_role_environment "$candidate"
        jq_apply "$candidate" '.password = ""'
    fi
    apply_game_settings_environment "$candidate"

    chmod 0600 "$candidate"
    existing_mode="$(stat -c '%a' "$ENSHROUDED_CONFIG_PATH" 2>/dev/null || true)"
    if cmp -s "$candidate" "$ENSHROUDED_CONFIG_PATH"; then
        rm -f "$candidate"
        if [ "$existing_mode" != "600" ]; then
            chmod 0600 "$ENSHROUDED_CONFIG_PATH"
        fi
    else
        mv "$candidate" "$ENSHROUDED_CONFIG_PATH"
        chmod 0600 "$ENSHROUDED_CONFIG_PATH"
        log "Updated Enshrouded server configuration at $ENSHROUDED_CONFIG_PATH" "$HOOK_NAME"
    fi
}

absolute_path_required ENSHROUDED_CONFIG_PATH "$ENSHROUDED_CONFIG_PATH"
absolute_path_required ENSHROUDED_SAVE_PATH "$ENSHROUDED_SAVE_PATH"
absolute_path_required ENSHROUDED_LOG_PATH "$ENSHROUDED_LOG_PATH"

mkdir -p "$WORLD_FILES"

persist_directory "$ENSHROUDED_SAVE_LINK" "$ENSHROUDED_SAVE_PATH"
persist_directory "$ENSHROUDED_LOG_LINK" "$ENSHROUDED_LOG_PATH"
persist_file "$ENSHROUDED_CONFIG_LINK" "$ENSHROUDED_CONFIG_PATH"

if [ ! -e "$ENSHROUDED_CONFIG_PATH" ]; then
    create_initial_config
fi

reconcile_config

if [ ! -f "$APP_FILES/enshrouded_server.exe" ]; then
    fail "Enshrouded executable not found after SteamCMD update: $APP_FILES/enshrouded_server.exe"
    return 1
fi

log "Enshrouded persistence and JSON configuration are ready" "$HOOK_NAME"
