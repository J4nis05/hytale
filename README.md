# Hytale Dedicated Server - Docker

A reproducible Docker image that automatically downloads and runs the latest Hytale dedicated server without embedding copyrighted binaries.

## Features

- Automatic downloader bootstrap from official Hytale sources
- Version management with conditional downloads (only downloads when updates are available)
- Persistent volumes for data, backups, and credentials
- Configurable via environment variables
- First-run authentication flow handling

## Quick Start

### 1. Setup and Run

```bash
# Create data directories
mkdir -p ./hytale/{downloader,server,data,backups,mods}

# Run the container (first run requires authentication)
docker compose up
```

### 2. First-Run Authentication

On first run, two authentication steps are required:

1. **Downloader Authentication**: The hytale-downloader will prompt for device-code authentication. Follow the CLI instructions to authenticate.

2. **Server Authentication**: If no `auth.enc` exists, the server will run boot commands to authenticate. Follow the in-game authentication prompts.

### 3. Persist Credentials

After initial authentication, bind-mount the credentials file to avoid re-authentication:

```yaml
volumes:
  - ./credentials/.hytale-downloader-credentials.json:/downloader/.hytale-downloader-credentials.json:ro
```

## Volume Mappings

| Volume | Path | Description |
|--------|------|-------------|
| `hytale-downloader` | `/downloader` | Downloader binary, credentials, version cache, and downloaded archives |
| `hytale-server` | `/server` | Unpacked server runtime (HytaleServer.jar, HytaleServer.aot, Licences) |
| `hytale-data` | `/data` | Assets.zip, worlds, configs, auth.enc, logs, saves |
| `hytale-backups` | `/backups` | Backup storage |
| `hytale-mods` | `/mods` | Additional mods directory |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HY_SERVER_ADDRESS` | `0.0.0.0` | Server bind address |
| `HY_SERVER_PORT` | `5520` | Server port (UDP) |
| `HY_ACCEPT_EARLY_PLUGINS` | `false` | Accept early plugins (unsupported, may cause stability issues) |
| `HY_ALLOW_OP` | `false` | Allow operator commands |
| `HY_SINGLEPLAYER` | `false` | Singleplayer mode |
| `HY_BACKUP_FREQUENCY` | `30` | Backup frequency in minutes |
| `HY_BACKUP_MAX_COUNT` | `5` | Maximum number of backups to retain |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 5520 | UDP | Hytale server port |

## Docker Compose Example

```yaml
version: "3.8"

services:
  hytale-server:
    image: j4nis05/hytale-server:latest
    container_name: hytale-server
    restart: unless-stopped
    ports:
      - "5520:5520/udp"
    environment:
      - HY_SERVER_ADDRESS=0.0.0.0
      - HY_SERVER_PORT=5520
      - HY_ACCEPT_EARLY_PLUGINS=false
      - HY_ALLOW_OP=false
      - HY_SINGLEPLAYER=false
      - HY_BACKUP_FREQUENCY=30
      - HY_BACKUP_MAX_COUNT=5
    volumes:
      - hytale-downloader:/downloader
      - hytale-server:/server
      - hytale-data:/data
      - hytale-backups:/backups
      - hytale-mods:/mods
    stdin_open: true
    tty: true

# Option 1: Named volumes (managed by Docker)
# volumes:
#   hytale-downloader:
#   hytale-server:
#   hytale-data:
#   hytale-backups:
#   hytale-mods:

# Option 2: Direct folder path mounts (recommended for game servers)
# Create directories first: mkdir -p ./hytale/{downloader,server,data,backups,mods}
volumes:
  hytale-downloader:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./hytale/downloader
  hytale-server:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./hytale/server
  hytale-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./hytale/data
  hytale-backups:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./hytale/backups
  hytale-mods:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./hytale/mods
```

## How It Works

### Bootstrap Flow

1. On container start, the entrypoint script ensures `/downloader` exists
2. Fetches `hytale-downloader.zip` from the official Hytale URL
3. Extracts and sets executable permissions on the Linux binary
4. Cleans up the downloaded ZIP

### Version Management

1. Runs `./hytale-downloader-linux-amd64 -print-version` to get the latest version
2. Compares against cached version in `/downloader/version.txt`
3. If versions match and server files exist, skips download
4. Otherwise, downloads the new version and extracts it

### Extraction Strategy

1. Creates a temp directory and extracts the version archive
2. Moves `Assets.zip` to `/data/Assets.zip`
3. Replaces `/server` contents with the new `Server/` directory
4. Cleans up temp files and the downloaded archive

### Server Launch

1. Validates that `Assets.zip` and `HytaleServer.jar` exist
2. Constructs command-line arguments from environment variables
3. If `auth.enc` is missing, adds boot commands for authentication
4. Launches the server from `/data` directory

## Server Help Menu

```
Option                                   Description
------                                   -----------
--accept-early-plugins                   You acknowledge that loading early
                                           plugins is unsupported and may cause
                                           stability issues.
--allow-op
--assets <Path>                          Asset directory (default: ..
                                           /HytaleAssets)
--auth-mode                              Authentication mode (default:
  <authenticated|offline|insecure>         AUTHENTICATED)
-b, --bind <InetSocketAddress>           Port to listen on (default: 0.0.0.0/0.
                                           0.0.0:5520)
--backup
--backup-dir <Path>
--backup-frequency <Integer>             (default: 30)
--backup-max-count <Integer>             (default: 5)
--bare                                   Runs the server bare. For example
                                           without loading worlds, binding to
                                           ports or creating directories.
                                           (Note: Plugins will still be loaded
                                           which may not respect this flag)
--boot-command <String>                  Runs command on boot. If multiple
                                           commands are provided they are
                                           executed synchronously in order.
--client-pid <Integer>
--disable-asset-compare
--disable-cpb-build                      Disables building of compact prefab
                                           buffers
--disable-file-watcher
--disable-sentry
--early-plugins <Path>                   Additional early plugin directories to
                                           load from
--event-debug
--force-network-flush <Boolean>          (default: true)
--generate-schema                        Causes the server generate schema,
                                           save it into the assets directory
                                           and then exit
--help                                   Print's this message.
--identity-token <String>                Identity token (JWT)
--log <KeyValueHolder>                   Sets the logger level.
--migrate-worlds <String>                Worlds to migrate
--migrations <Object2ObjectOpenHashMap>  The migrations to run
--mods <Path>                            Additional mods directories
--owner-name <String>
--owner-uuid <UUID>
--prefab-cache <Path>                    Prefab cache directory for immutable
                                           assets
--session-token <String>                 Session token for Session Service API
--shutdown-after-validate                Automatically shutdown the server
                                           after asset and/or prefab validation.
--singleplayer
-t, --transport <TransportType>          Transport type (default: QUIC)
--universe <Path>
--validate-assets                        Causes the server to exit with an
                                           error code if any assets are invalid.
--validate-prefabs [ValidationOption]    Causes the server to exit with an
                                           error code if any prefabs are
                                           invalid.
--validate-world-gen                     Causes the server to exit with an
                                           error code if default world gen is
                                           invalid.
--version                                Prints version information.
--world-gen <Path>                       World gen directory
```

## Troubleshooting

### Downloader Authentication Fails

Ensure you have an active internet connection and can reach `downloader.hytale.com`. The device-code flow requires browser access.

### Server Won't Start

1. Check that `Assets.zip` exists in `/data`
2. Check that `HytaleServer.jar` exists in `/server`
3. Review container logs: `docker compose logs -f`

### Repeated Authentication Prompts

Bind-mount the credentials file to persist authentication:

```yaml
volumes:
  - ./credentials/.hytale-downloader-credentials.json:/downloader/.hytale-downloader-credentials.json:ro
```

### Port Already in Use

Change `HY_SERVER_PORT` and update the port mapping in `docker-compose.yml`:

```yaml
ports:
  - "5521:5521/udp"
environment:
  - HY_SERVER_PORT=5521
```
