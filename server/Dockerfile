# =============================================================================
# Hytale Dedicated Server - Docker Image
# =============================================================================
# This image provides a reproducible environment for running the Hytale
# dedicated server. It automatically downloads the latest server version
# without embedding copyrighted binaries.
# =============================================================================

FROM debian:trixie-slim

LABEL maintainer="Hytale Docker Community"
LABEL description="Hytale Dedicated Server - Dockerized"
LABEL version="1.0.0"

# Install required dependencies:
# - bash:                    Shell for entrypoint script
# - curl:                    For downloading the hytale-downloader
# - unzip:                   For extracting archives
# - ca-certificates:         For HTTPS connections
# - coreutils:               Basic utilities
# - openjdk-25-jre-headless: Java runtime for HytaleServer.jar
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    unzip \
    ca-certificates \
    coreutils \
    openjdk-25-jre-headless \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create directory structure
RUN mkdir -p /downloader /server /data /backups /mods

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables with defaults
ENV HY_SERVER_ADDRESS=0.0.0.0
ENV HY_SERVER_PORT=5520
ENV HY_ACCEPT_EARLY_PLUGINS=false
ENV HY_ALLOW_OP=false
ENV HY_SINGLEPLAYER=false
ENV HY_BACKUP_FREQUENCY=30
ENV HY_BACKUP_MAX_COUNT=5

# /downloader:  hytale-downloader binary, credentials, version cache, and archives
# /server:      unpacked server runtime (HytaleServer.jar, HytaleServer.aot, Licences)
# /data:        Assets.zip, worlds, configs, runtime working directory
# /backups:     backup storage
# /mods:        additional mods directory
VOLUME ["/downloader", "/server", "/data", "/backups", "/mods"]

EXPOSE 5520/udp

# For initial Operations:
WORKDIR /downloader

ENTRYPOINT ["/entrypoint.sh"]
