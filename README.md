# Docker Enshrouded Server Images

This Docker image provides a Enshrouded dedicated server, supporting **both `amd64` and `arm64` (x86, arm) architectures.**

![Teriyakidactyl Delivers!™](/images/repo.png)

**_Teriyakidactyl Delivers!™_**

## Features

- Supports `amd64` and `arm64` architectures
- Mod manager via `SERVER_MOD_IDS`
- Runs under non-root user
- Automatic server updates via [steamcmd](https://developer.valvesoftware.com/wiki/SteamCMD) (on reboot)
- Cross-platform compatibility using [Box86](https://github.com/ptitSeb/box86)/[Box64](https://github.com/ptitSeb/box64) for `arm64` systems (tested on [Oracle Ampere](https://www.oracle.com/cloud/compute/arm/))
- Colored :rainbow: (even in Portainer), organized logs (under development)

## Environment Variables

Configure your server using the following environment variables:

- `SERVER_PLAYER_PASS`: Server password (default: "MySecretPassword")
- `SERVER_ADMIN_PASS`: Server password (default: "MySecretPasswordAdmin")
- `SERVER_NAME`: Server name (default: "Teriyakolypse")
- `SERVER_REGION_ID`: [Region ID](https://shockbyte.com/billing/knowledgebase/706/How-to-Change-your-Visible-Server-Region-in-ENSHROUDED-Exiles.html), (default: 1, 'North-America')
- `SERVER_MOD_IDS`: Example: 3039478786,2879367569
- `SERVER_ALLOW_LIST`: List of [SteamID64](https://www.steamidfinder.com/) strings to indicate allowed players (default: empty, allow-all).  
- `SERVER_NUDITY_POLICY`: 0 none, 1 partial, 2 full (default: 0)

## Usage

1. Pull the image:
   
```bash
docker pull ghcr.io/teriyakidactyl/docker-ENSHROUDED-exiles-server:latest
```

2. Run the container:
   
```bash
UR_PATH="/root/ENSHROUDED"
mkdir -p $UR_PATH/world  $UR_PATH/app

docker run -d \
-e SERVER_NAME="Teriyakolypse" \
-e SERVER_PLAYER_PASS="MySecretPassword" \
-e SERVER_ADMIN_PASS="MySecretPasswordAdmin" \
-v $UR_PATH/world:/world \
-v $UR_PATH/app:/app \
-p 7777-7778:7777-7778/udp \
--name ENSHROUDED-Exiles-Server \
ghcr.io/teriyakidactyl/docker-ENSHROUDED-exiles-server:latest

```

Replace `UR_PATH="/root/ENSHROUDED"` with the path where you want to store your app/world data.

## Building the Image

To build the image yourself:

```docker build -t ghcr.io/teriyakidactyl/docker-ENSHROUDED-exiles-server:latest .```

## Healthcheck

The container includes a basic healthcheck that verifies if the ENSHROUDED server process is running.

## Support

For issues, feature requests, or contributions, please use the GitHub issue tracker.
