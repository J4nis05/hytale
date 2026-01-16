# Hytale Dockerized Dedicated Server Plan

## Goals
- Provide a reproducible Docker image that always ships the latest Hytale dedicated server without embedding copyrighted binaries.
- Automate downloader bootstrap, version comparison, conditional fetching, extraction, and runtime startup from `/data`.
- Expose documented volumes, ports, and environment variables so operators can persist state and control server behavior.

## Directory Layout & Volumes
- `/downloader` (volume): houses `hytale-downloader-linux-amd64`, `.hytale-downloader-credentials.json`, version cache, and downloaded archives. Must be persisted/mounted.
- `/server` (volume): contains the unpacked server runtime (`HytaleServer.jar`, `HytaleServer.aot`, `Licences`). Entire directory replaced each update.
- `/data` (volume): stores `Assets.zip`, generated worlds, configs, and the runtime working directory (`auth.enc`, logs, saves). Server process runs from here.
- `/backups` (volume): target for `--backup-dir`.
- `/mods` (volume): additional mods directory mounted for `--mods` flag.

## Downloader Bootstrap Flow
1. On container start, ensure `/downloader` exists (mkdir -p) and becomes working directory for download operations.
2. Fetch `https://downloader.hytale.com/hytale-downloader.zip` to `/downloader/hytale-downloader.zip` using `curl -L --retry`.
3. Unzip the archive in place; retain both linux and windows builds for completeness.
4. Set executable bit on `/downloader/hytale-downloader-linux-amd64`.
5. Delete the downloaded ZIP to keep directory tidy.
6. Documentation note: instruct operators to bind-mount `/downloader/.hytale-downloader-credentials.json` (created post-auth) for persistent tokens.

## Authentication & Credential Handling
- First run requires device-code authentication invoked by the downloader; user follows CLI instructions and resulting `.hytale-downloader-credentials.json` is written alongside the binary.
- Script should detect presence of this file; if missing, warn that manual auth will be required after the `./hytale-downloader-linux-amd64` invocation begins.
- No credentials stored in image; rely entirely on mounted `/downloader` volume.

## Version Management & Conditional Downloads
1. Run `./hytale-downloader-linux-amd64 -print-version` inside `/downloader` and capture output as `latest_version`.
2. Compare against `/downloader/version.txt` (if exists). If identical, skip download and reuse current `/server` & `/data/Assets.zip`.
3. If `version.txt` missing or differs, execute `./hytale-downloader-linux-amd64` (without args) to download `<latest_version>.zip` to `/downloader`.
4. After successful extraction (see below), update `/downloader/version.txt` to `latest_version` and optionally remove the zip to save space.

## Server Payload Extraction Strategy
1. Create temp directory inside `/downloader` (e.g., `tmp_extract`) and unzip `<latest_version>.zip` there.
2. The archive root contains `Assets.zip` and `Server/` directory.
3. Move `tmp_extract/Assets.zip` to `/data/Assets.zip`, overwriting existing file atomically (e.g., via `mv` after ensuring parent dir).
4. Replace `/server` contents:
   - Remove everything under `/server` (e.g., `rm -rf /server/*`) but leave mount intact.
   - Move `tmp_extract/Server/*` into `/server`.
5. Clean up temp directory and the downloaded `<latest_version>.zip` to conserve space.

## Container Image Layout
- Base image: Debian/Ubuntu slim with `bash`, `curl`, `unzip`, `ca-certificates`, `coreutils`, and Java runtime compatible with `HytaleServer.jar` (likely OpenJDK 21+; verify actual requirement).
- Copy entrypoint script (e.g., `/entrypoint.sh`) responsible for bootstrap, version check, extraction, and server launch.
- Set working directory to `/downloader` for downloader steps, switch to `/data` before launching server.
- Declare volumes for `/downloader`, `/server`, `/data`, `/backups`, `/mods`.
- Expose UDP 5520 (`EXPOSE 5520/udp`).

## Runtime Environment Variables & Defaults
- `HY_SERVER_ADDRESS` (default `0.0.0.0`).
- `HY_SERVER_PORT` (default `5520`).
- `HY_ACCEPT_EARLY_PLUGINS` (default `false`).
- `HY_ALLOW_OP` (default `false`).
- `HY_SINGLEPLAYER` (default `false`).
- `HY_BACKUP_FREQUENCY` (default `30`).
- `HY_BACKUP_MAX_COUNT` (default `5`).
- Potential future: `HY_BOOT_COMMANDS` for additional custom commands beyond auth bootstrap.
- Script translates booleans into presence/absence of flags; numbers must be validated integers.

## Server Launch Command Assembly
1. Ensure `/data/Assets.zip` and `/server/HytaleServer.jar` exist; abort with informative error otherwise.
2. Construct argument list baseline:
   - `--assets /data/Assets.zip`
   - `--backup-dir /backups`
   - `--mods /mods`
   - `--bind ${HY_SERVER_ADDRESS:-0.0.0.0}:${HY_SERVER_PORT:-5520}`
   - `--backup-frequency ${HY_BACKUP_FREQUENCY:-30}`
   - `--backup-max-count ${HY_BACKUP_MAX_COUNT:-5}`
3. Append optional flags when envs evaluate truthy: `--accept-early-plugins`, `--allow-op`, `--singleplayer`.
4. If `/data/auth.enc` is absent, prepend `--boot-command "auth persistence Encrypted"` and `--boot-command "auth login device"` to ensure authentication commands run once.
5. Run from `/data`: `cd /data && java -jar /server/HytaleServer.jar "${args[@]}"` (validate if additional JVM flags required).

## Documentation & Usage Guidance
- Update README to describe volume mappings, required envs, and first-run auth flow (device code for downloader, boot commands for server).
- Highlight that `/downloader/.hytale-downloader-credentials.json` should be bind-mounted or copied in prior to run to avoid repeated auth prompts.
- Provide docker-compose snippet demonstrating env vars, volumes, and UDP port exposure.

## Validation & Future Enhancements
- Smoke-test container locally by running entrypoint with mocked downloader (or allow manual auth) to verify download, extraction, and startup.
- Consider caching assets if version unchanged but directories missing, to avoid unnecessary downloads.
- Potential addition: cron or sidecar job for backups beyond built-in frequency, but out of scope for initial plan.
