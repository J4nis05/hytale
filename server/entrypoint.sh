#!/bin/bash
set -e

# =============================================================================
# Hytale Dedicated Server Docker Entrypoint
# =============================================================================
# This script handles:
# 1. Downloader bootstrap (fetch and setup hytale-downloader)
# 2. Version management (conditional downloads)
# 3. Server payload extraction
# 4. Server launch with proper configuration
# =============================================================================

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Configuration - Environment Variables with Defaults
# =============================================================================
HY_SERVER_ADDRESS="${HY_SERVER_ADDRESS:-0.0.0.0}"
HY_SERVER_PORT="${HY_SERVER_PORT:-5520}"
HY_ACCEPT_EARLY_PLUGINS="${HY_ACCEPT_EARLY_PLUGINS:-false}"
HY_ALLOW_OP="${HY_ALLOW_OP:-false}"
HY_SINGLEPLAYER="${HY_SINGLEPLAYER:-false}"
HY_BACKUP_FREQUENCY="${HY_BACKUP_FREQUENCY:-30}"
HY_BACKUP_MAX_COUNT="${HY_BACKUP_MAX_COUNT:-5}"

# Directory paths
DOWNLOADER_DIR="/downloader"
SERVER_DIR="/server"
DATA_DIR="/data"
BACKUPS_DIR="/backups"
MODS_DIR="/mods"

DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
DOWNLOADER_ZIP="${DOWNLOADER_DIR}/hytale-downloader.zip"
DOWNLOADER_BIN="${DOWNLOADER_DIR}/hytale-downloader-linux-amd64"
CREDENTIALS_FILE="${DOWNLOADER_DIR}/.hytale-downloader-credentials.json"
VERSION_FILE="${DOWNLOADER_DIR}/version.txt"

# =============================================================================
# Helper Functions
# =============================================================================

validate_integer() {
    local value="$1"
    local name="$2"
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        log_error "$name must be a valid integer, got: $value"
        exit 1
    fi
}

is_truthy() {
    local value="${1,,}" # lowercase
    [[ "$value" == "true" || "$value" == "1" || "$value" == "yes" ]]
}

# =============================================================================
# Step 1: Downloader Bootstrap
# =============================================================================
bootstrap_downloader() {
    log_info "=== Downloader Bootstrap ==="
    
    # Ensure downloader directory exists
    mkdir -p "$DOWNLOADER_DIR"
    cd "$DOWNLOADER_DIR"
    
    # Check if downloader binary already exists
    if [[ -x "$DOWNLOADER_BIN" ]]; then
        log_info "Downloader binary already exists, skipping bootstrap"
        return 0
    fi
    
    log_info "Fetching hytale-downloader from $DOWNLOADER_URL"
    curl -L --retry 3 --retry-delay 5 -o "$DOWNLOADER_ZIP" "$DOWNLOADER_URL"
    
    if [[ ! -f "$DOWNLOADER_ZIP" ]]; then
        log_error "Failed to download hytale-downloader.zip"
        exit 1
    fi
    
    log_info "Extracting downloader archive..."
    unzip -o "$DOWNLOADER_ZIP" -d "$DOWNLOADER_DIR"
    
    # Set executable bit
    if [[ -f "$DOWNLOADER_BIN" ]]; then
        chmod +x "$DOWNLOADER_BIN"
        log_success "Downloader binary ready at $DOWNLOADER_BIN"
    else
        log_error "Downloader binary not found after extraction"
        exit 1
    fi
    
    # Clean up the zip file
    rm -f "$DOWNLOADER_ZIP"
    log_info "Cleaned up downloader archive"
}

# =============================================================================
# Step 2: Authentication & Credential Handling
# =============================================================================
check_credentials() {
    log_info "=== Checking Credentials ==="
    
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        log_success "Credentials file found at $CREDENTIALS_FILE"
        return 0
    else
        log_warn "Credentials file not found at $CREDENTIALS_FILE"
        log_warn "Device-code authentication will be required on first run."
        log_warn "Follow the CLI instructions when prompted."
        log_warn "Tip: Bind-mount $CREDENTIALS_FILE for persistent tokens."
        return 1
    fi
}

# =============================================================================
# Step 3: Version Management & Conditional Downloads
# =============================================================================
check_and_download() {
    log_info "=== Version Management ==="
    
    cd "$DOWNLOADER_DIR"
    
    # Get latest version from downloader
    log_info "Checking latest server version..."
    local latest_version
    latest_version=$("$DOWNLOADER_BIN" -print-version 2>&1) || {
        log_error "Failed to get latest version. Output: $latest_version"
        exit 1
    }
    log_info "Latest version: $latest_version"
    
    # Check cached version
    local cached_version=""
    if [[ -f "$VERSION_FILE" ]]; then
        cached_version=$(cat "$VERSION_FILE")
        log_info "Cached version: $cached_version"
    else
        log_info "No cached version found"
    fi
    
    # Compare versions
    if [[ "$latest_version" == "$cached_version" ]]; then
        # Verify that server files exist
        if [[ -f "$SERVER_DIR/HytaleServer.jar" && -f "$DATA_DIR/Assets.zip" ]]; then
            log_success "Version unchanged and server files present, skipping download"
            return 0
        else
            log_warn "Version unchanged but server files missing, re-downloading"
        fi
    fi
    
    # Download new version
    log_info "Downloading server version $latest_version..."
    "$DOWNLOADER_BIN"
    
    local version_zip="${DOWNLOADER_DIR}/${latest_version}.zip"
    if [[ ! -f "$version_zip" ]]; then
        log_error "Expected archive not found: $version_zip"
        exit 1
    fi
    
    # Extract and deploy
    extract_server_payload "$version_zip" "$latest_version"
    
    # Update version cache
    echo "$latest_version" > "$VERSION_FILE"
    log_success "Version cache updated to $latest_version"
    
    # Clean up downloaded archive to save space
    rm -f "$version_zip"
    log_info "Cleaned up downloaded archive"
}

# =============================================================================
# Step 4: Server Payload Extraction
# =============================================================================
extract_server_payload() {
    local archive="$1"
    local version="$2"
    
    log_info "=== Extracting Server Payload ==="
    
    local tmp_dir="${DOWNLOADER_DIR}/tmp_extract"
    
    # Create temp directory
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"
    
    log_info "Extracting $archive to $tmp_dir..."
    unzip -o "$archive" -d "$tmp_dir"
    
    # Ensure target directories exist
    mkdir -p "$SERVER_DIR"
    mkdir -p "$DATA_DIR"
    
    # Move Assets.zip to /data
    if [[ -f "$tmp_dir/Assets.zip" ]]; then
        log_info "Moving Assets.zip to $DATA_DIR/"
        mv -f "$tmp_dir/Assets.zip" "$DATA_DIR/Assets.zip"
    else
        log_error "Assets.zip not found in archive"
        exit 1
    fi
    
    # Replace /server contents
    if [[ -d "$tmp_dir/Server" ]]; then
        log_info "Replacing $SERVER_DIR contents..."
        rm -rf "$SERVER_DIR"/*
        mv -f "$tmp_dir/Server"/* "$SERVER_DIR/"
    else
        log_error "Server/ directory not found in archive"
        exit 1
    fi
    
    # Clean up temp directory
    rm -rf "$tmp_dir"
    log_success "Server payload extraction complete"
}

# =============================================================================
# Step 5: Server Launch
# =============================================================================
launch_server() {
    log_info "=== Launching Hytale Server ==="
    
    # Validate required files exist
    if [[ ! -f "$DATA_DIR/Assets.zip" ]]; then
        log_error "Assets.zip not found at $DATA_DIR/Assets.zip"
        exit 1
    fi
    
    if [[ ! -f "$SERVER_DIR/HytaleServer.jar" ]]; then
        log_error "HytaleServer.jar not found at $SERVER_DIR/HytaleServer.jar"
        exit 1
    fi
    
    # Validate integer environment variables
    validate_integer "$HY_SERVER_PORT" "HY_SERVER_PORT"
    validate_integer "$HY_BACKUP_FREQUENCY" "HY_BACKUP_FREQUENCY"
    validate_integer "$HY_BACKUP_MAX_COUNT" "HY_BACKUP_MAX_COUNT"
    
    # Ensure backup and mods directories exist
    mkdir -p "$BACKUPS_DIR"
    mkdir -p "$MODS_DIR"
    
    # Build argument list
    local args=()
    
    # Required arguments
    args+=("--assets" "$DATA_DIR/Assets.zip")
    args+=("--backup-dir" "$BACKUPS_DIR")
    args+=("--mods" "$MODS_DIR")
    args+=("--bind" "${HY_SERVER_ADDRESS}:${HY_SERVER_PORT}")
    args+=("--backup-frequency" "$HY_BACKUP_FREQUENCY")
    args+=("--backup-max-count" "$HY_BACKUP_MAX_COUNT")
    
    # Optional boolean flags
    if is_truthy "$HY_ACCEPT_EARLY_PLUGINS"; then
        args+=("--accept-early-plugins")
        log_info "Early plugins acceptance enabled"
    fi
    
    if is_truthy "$HY_ALLOW_OP"; then
        args+=("--allow-op")
        log_info "Self OP Enabled"
    fi
    
    if is_truthy "$HY_SINGLEPLAYER"; then
        args+=("--singleplayer")
        log_info "Singleplayer mode enabled"
    fi
    
    # Check for auth.enc and add boot commands if missing
    if [[ ! -f "$DATA_DIR/auth.enc" ]]; then
        log_info "No auth.enc found, adding authentication boot commands"
        args+=("--boot-command" "auth persistence Encrypted")
        args+=("--boot-command" "auth login device")
    fi
    
    # Change to data directory and launch
    cd "$DATA_DIR"
    
    log_info "Starting server with arguments:"
    log_info "  ${args[*]}"
    
    exec java -jar "$SERVER_DIR/HytaleServer.jar" "${args[@]}"
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    log_info "=========================================="
    log_info "  Hytale Dedicated Server - Docker"
    log_info "=========================================="
    
    # Step 1: Download the Downloader
    bootstrap_downloader
    
    # Step 2: Check for existing Downloader credentials (warn if missing)
    check_credentials || true
    
    # Step 3: Version check and conditional download
    check_and_download
    
    # Step 4: Launch server
    launch_server
}

main "$@"
