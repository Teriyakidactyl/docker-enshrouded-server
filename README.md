# Docker Enshrouded Server Images

Multi-architecture Enshrouded dedicated-server image built on
[`docker-steamcmd-server`](https://github.com/Teriyakidactyl/docker-steamcmd-server).
The shared base owns SteamCMD, Wine/Proton, Box64, compatibility prefixes,
process supervision, health checks, and shutdown. This repository owns only the
Enshrouded application contract, JSON configuration, and persistence topology.

![Teriyakidactyl Delivers!™](./images/repo.png)

## Runtime model

Enshrouded's dedicated-server Steam app (`2278520`) is currently Windows-only.
The published image hides that implementation detail behind the shared base:

| Image architecture | Preferred shared-base runtime |
| --- | --- |
| `amd64` | Trixie + GE-Proton 11.7 |
| `arm64` | Trixie + Wine staging + base-owned Box64 |

The Enshrouded child image does not invoke Proton, Wine, Box64, or SteamCMD
itself. It declares `STEAM_PLATFORM_TYPE=windows` and
`APP_EXE=enshrouded_server.exe`; the selected base image composes the runtime.

`latest` and `trixie` are multi-architecture manifests containing the preferred
runtime for each architecture. `bookworm` is also published, using Proton 10.34
on amd64 and Wine staging on arm64.

## Persistence

Keep both `/app` and `/world` persistent:

| Path | Ownership |
| --- | --- |
| `/app` | Steam installation, Steam client state, and Wine/Proton compatibility state |
| `/world` | Operator-owned Enshrouded configuration, saves, and logs |

After SteamCMD updates, the pre-start hook repairs these application-facing
paths at runtime:

| Application path | Persistent target |
| --- | --- |
| `/app/enshrouded_server.json` | `/world/enshrouded_server.json` |
| `/app/savegame` | `/world/savegame` |
| `/app/logs` | `/world/logs` |

If an older application volume already contains a config/save/log path, missing
content is adopted into `/world` before the stable link is restored. Existing
`/world` state wins when both sides exist.

## First start and passwords

On a brand-new server, the image creates the current Enshrouded JSON structure
with Admin, Friend, and Guest roles. Each role receives a randomized password.
Passwords are **not printed to container logs**. Read or replace them in
`/world/enshrouded_server.json`, or explicitly configure role passwords through
environment variables before first start.

For example:

```yaml
environment:
  SERVER_ROLE_0_NAME: Admin
  SERVER_ROLE_0_PASSWORD: change-me-admin
  SERVER_ROLE_1_NAME: Friend
  SERVER_ROLE_1_PASSWORD: change-me-friend
  SERVER_ROLE_2_NAME: Guest
  SERVER_ROLE_2_PASSWORD: change-me-guest
```

The historical `SERVER_ADMIN_PASS` and `SERVER_PLAYER_PASS`/`SERVER_PASSWORD`
variables remain migration aliases. They map to role 0 and role 1 passwords,
respectively, when the corresponding modern role password variable is absent.
New deployments should use `SERVER_ROLE_<index>_*`.

## Core configuration

The runtime hook reconciles the following documented Enshrouded settings while
preserving unknown/native JSON fields:

| Variable | Default | JSON field |
| --- | --- | --- |
| `SERVER_NAME` | `Enshrouded Server` | `name` |
| `SERVER_IP` | `0.0.0.0` | `ip` |
| `SERVER_QUERY_PORT` | `15637` | `queryPort` |
| `SERVER_SLOT_COUNT` | `16` | `slotCount` (1–16) |
| `SERVER_VOICE_CHAT_MODE` | `Proximity` | `voiceChatMode` (`Proximity` or `Global`) |
| `SERVER_ENABLE_VOICE_CHAT` | `false` | `enableVoiceChat` |
| `SERVER_ENABLE_TEXT_CHAT` | `false` | `enableTextChat` |
| `SERVER_GAME_SETTINGS_PRESET` | `Default` | `gameSettingsPreset` |

`saveDirectory` and `logDirectory` are intentionally container-owned as
`./savegame` and `./logs` so the `/world` persistence contract cannot be
silently bypassed by an environment change.

The official configuration reference is:
<https://enshrouded.zendesk.com/hc/en-us/articles/16055441447709-Dedicated-Server-Configuration>

## Server roles

Indexed role variables map directly to `userGroups[index]`:

- `SERVER_ROLE_<index>_NAME`
- `SERVER_ROLE_<index>_PASSWORD`
- `SERVER_ROLE_<index>_CAN_KICK_BAN`
- `SERVER_ROLE_<index>_CAN_ACCESS_INVENTORIES`
- `SERVER_ROLE_<index>_CAN_EDIT_WORLD`
- `SERVER_ROLE_<index>_CAN_EDIT_BASE`
- `SERVER_ROLE_<index>_CAN_EXTEND_BASE`
- `SERVER_ROLE_<index>_RESERVED_SLOTS`

Only explicitly supplied role fields are replaced; other fields and groups are
preserved. Boolean role values must be `true` or `false`, and reserved slots
must be between 0 and 16.

The current role model is documented upstream at:
<https://enshrouded.zendesk.com/hc/en-us/articles/19191581489309-Server-Roles-Configuration>

## Advanced game settings

`SERVER_GS_*` variables provide a forward-compatible path for Enshrouded game
settings without requiring an image release whenever Keen adds a new key. The
suffix is converted from uppercase snake case to JSON lower camel case under
`gameSettings`.

For example:

```yaml
environment:
  SERVER_GAME_SETTINGS_PRESET: Custom
  SERVER_GS_PLAYER_HEALTH_FACTOR: "1.25"
  SERVER_GS_ENABLE_STARVING_DEBUFF: "false"
```

becomes conceptually:

```json
{
  "gameSettingsPreset": "Custom",
  "gameSettings": {
    "playerHealthFactor": 1.25,
    "enableStarvingDebuff": false
  }
}
```

`SERVER_GS_PRESET` is also accepted as an alias for `gameSettingsPreset`.
Numbers and booleans are written as JSON values; other values are strings.

## Docker Compose

```bash
docker compose up -d
```

The included Compose file uses named volumes for `/app` and `/world`, publishes
the default `15637/udp` query port, and gives Enshrouded 100 seconds of Docker
stop grace time.

To use bind mounts instead:

```yaml
volumes:
  - ./app:/app
  - ./world:/world
```

## Docker run

```bash
UR_PATH="/root/enshrouded"
mkdir -p "$UR_PATH/app" "$UR_PATH/world"

docker run -d \
  --name Enshrouded-Server \
  --restart unless-stopped \
  --stop-timeout 100 \
  -e SERVER_NAME="My Enshrouded Server" \
  -e SERVER_ROLE_0_PASSWORD="change-me-admin" \
  -v "$UR_PATH/app:/app" \
  -v "$UR_PATH/world:/world" \
  -p 15637:15637/udp \
  ghcr.io/teriyakidactyl/docker-enshrouded-server:latest
```

## Shutdown

The image uses `APP_STOP_SIGNAL=INT` and a 90-second internal shutdown ceiling.
The shared supervisor signals the complete launched process group and escalates
only if it remains alive after that timeout. Docker examples use a 100-second
outer grace period.

## Updates

`UPDATE_ON_START=true` is inherited from the shared base. SteamCMD checks app
`2278520` before launch and downloads the Windows depot when an update is
required. `STEAM_VALIDATE=true` enables SteamCMD validation.

Scheduled in-place updates, backups, and player-aware update deferral are not
part of the initial shared-base migration. They can be added later without
reintroducing a second process supervisor into this image.

## Building

A plain local build defaults to the cross-architecture Wine staging base:

```bash
docker build -t ghcr.io/teriyakidactyl/docker-enshrouded-server:local .
```

For the preferred amd64 runtime:

```bash
docker build \
  --build-arg BASE_TAG=trixie_proton-11.7 \
  -t ghcr.io/teriyakidactyl/docker-enshrouded-server:local .
```

The GitHub workflow selects the supported base tag per architecture and builds
on native amd64/arm64 runners.

## Health check

The image inherits the shared-base PID health check, which verifies the launched
Enshrouded application process remains alive.

## Support

For issues, feature requests, or contributions, use this repository's GitHub
issue tracker.
