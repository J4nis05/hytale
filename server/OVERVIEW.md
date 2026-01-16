# Hytale Dedicated Server

A Dedicated Hytale Server in Docker. It uses the Hytale Server Download CLI to automatically fetch the latest version on Boot.

Github: [https://github.com/J4nis05/hytale-server](https://github.com/J4nis05/hytale-server)


## Ports and Volumes

The Server uses Port `5520` over **UDP**.

| Container-Path | Description                                                                                          |
| -------------- | ---------------------------------------------------------------------------------------------------- |
| `/downloader`  | Contains the Downloader CLI. place the `.hytale-downloader-credentials.json` in here if you have one |
| `/server`      | Contains the `HytaleServer.jar` and `HytaleServer.aot`                                               |
| `/data`        | Contains the `Assets.zip` and World Data / Configuration Files                                       |
| `/backups`     | The Server stores the World / Player Backup Zip Files here                                           |
| `/mods`        | In case you want to add mods, place them here                                                        |


## Environment Variables

| Name                      | Default   | Description                                                                                 |
| ------------------------- | --------- | ------------------------------------------------------------------------------------------- |
| `HY_SERVER_ADDRESS`       | `0.0.0.0` | Bind Address the server should listen for connections on. 0.0.0.0 Means any IP can connect. |
| `HY_SERVER_PORT`          | `5520`    | Change the Port the Server should listen for connections on.                                |
| `HY_ACCEPT_EARLY_PLUGINS` | `false`   | Wether the Server allows Early Access Plugins                                               |
| `HY_ALLOW_OP`             | `false`   | Wether connected Players can run the `/op self` command to give them Administrator Rights.  |
| `HY_SINGLEPLAYER`         | `false`   | Wether the Server is Running a Singleplayer World or not.                                   |
| `HY_BACKUP_FREQUENCY`     | `30`      | World / Player Backup Interval in Minutes.                                                  |
| `HY_BACKUP_MAX_COUNT`     | `5`       | How many Backups to Keep at once                                                            |

Booleans accept `true|false|1|0|yes|no`. Port and backup values must be integers.


## Quick Start (docker compose)

```yaml
name: "hytale-server"

services:
  hytale-server:
    image: j4nis05/hytale-server:latest
    container_name: hytale-server
    restart: unless-stopped
    
    ports:
      - "5520:5520/udp"
    
    # Environment variables for server configuration
    environment:
      - HY_SERVER_ADDRESS=0.0.0.0     # Server bind address (default: 0.0.0.0)
      - HY_SERVER_PORT=5520           # Server port (default: 5520)
      - HY_ACCEPT_EARLY_PLUGINS=false # Accept early plugins - unsupported, may cause stability issues (default: false)
      - HY_ALLOW_OP=false             # Allow operator commands (default: false)
      - HY_SINGLEPLAYER=false         # Singleplayer mode (default: false)
      - HY_BACKUP_FREQUENCY=30        # Backup frequency in minutes (default: 30)
      - HY_BACKUP_MAX_COUNT=5         # Maximum number of backups to retain (default: 5)
    
    volumes:
      - hytale-downloader:/downloader # IMPORTANT: Mount credentials file here for persistent authentication
      - hytale-server:/server         # Server runtime: HytaleServer.jar and related files
      - hytale-data:/data             # Data directory: Assets.zip, worlds, configs, logs, saves
      - hytale-backups:/backups       # Backup storage
      - hytale-mods:/mods             # Mods directory
      
      # Optional: Bind-mount credentials file for persistent downloader auth
      # - ./credentials/.hytale-downloader-credentials.json:/downloader/.hytale-downloader-credentials.json
    
    # Interactive mode for initial authentication
    stdin_open: true
    tty: true

# Alternative: Direct folder path mounts (recommended for game servers)
# Create these directories before starting: mkdir -p /docker/games/hytale/{downloader,server,data,backups,mods}
volumes:
  hytale-downloader:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /docker/games/hytale/downloader
  hytale-server:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /docker/games/hytale/server
  hytale-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /docker/games/hytale/data
  hytale-backups:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /docker/games/hytale/backups
  hytale-mods:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /docker/games/hytale/mods


# Or: use Docker Volumes instead of mounts
# volumes:
#   hytale-downloader:
#     driver: local
#   hytale-server:
#     driver: local
#   hytale-data:
#     driver: local
#   hytale-backups:
#     driver: local
#   hytale-mods:
#     driver: local
```

Prepare directories once before starting:

```bash
mkdir -p /docker/games/hytale/{downloader,server,data,backups,mods}
```

## Quick Start (docker run)

```bash
mkdir -p ./hytale/{downloader,server,data,backups,mods}

docker run -it --name hytale-server --restart unless-stopped \
  -p 5520:5520/udp \
  -e HY_SERVER_ADDRESS=0.0.0.0 \
  -e HY_SERVER_PORT=5520 \
  -e HY_ACCEPT_EARLY_PLUGINS=false \
  -e HY_ALLOW_OP=false \
  -e HY_SINGLEPLAYER=false \
  -e HY_BACKUP_FREQUENCY=30 \
  -e HY_BACKUP_MAX_COUNT=5 \
  -v $(pwd)/hytale/downloader:/downloader \
  -v $(pwd)/hytale/server:/server \
  -v $(pwd)/hytale/data:/data \
  -v $(pwd)/hytale/backups:/backups \
  -v $(pwd)/hytale/mods:/mods \
  j4nis05/hytale-server:latest
```


## Authentication Flow

- Downloader: first run triggers device‑code auth in the container logs. Follow the CLI prompt to authenticate; a `.hytale-downloader-credentials.json` file is saved in `/downloader`.
- Server: if `/data/auth.enc` is missing, the container injects boot commands (`auth persistence Encrypted` and `auth login device`) so the server can complete authentication once, then persist it.

Mount `/downloader/.hytale-downloader-credentials.json` on subsequent runs to avoid repeated auth.

## How It Works

On startup the entrypoint:
1) Bootstraps the official `hytale-downloader` into `/downloader`
2) Detects the latest server version and compares with `/downloader/version.txt`
3) Downloads when needed, then extracts:
   - `Assets.zip` → `/data/Assets.zip`
   - `Server/` → `/server`
4) Launches the server from `/data` with arguments assembled from env vars

## Ports

- UDP `5520` exposed (map to host with `-p 5520:5520/udp`)

## Troubleshooting

- Missing `Assets.zip` or `HytaleServer.jar`: check volume mounts and allow the downloader to finish
- Repeated auth prompts: mount the credentials file into `/downloader`
- Logs: `docker logs -f hytale-server` or `docker compose logs -f`
