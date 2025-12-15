#!/bin/bash
set -euo pipefail

# Security settings
unset IFS
PATH="/usr/sbin:/usr/bin:/sbin:/bin"

# Logging and error handling (defined early to avoid SC2218)
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
    exit 1
}
warn() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*"; }

# Input validation functions
validate_input() {
    local input="$1"
    local type="$2"

    case "$type" in
    "path")
        # Check for path traversal attempts
        if [[ "$input" =~ \.\./|\.\. ]]; then
            error "Path traversal detected in: $input"
        fi
        # Check for null bytes
        if [[ "$input" =~ $'\0' ]]; then
            error "Null bytes detected in: $input"
        fi
        # Check for excessive length
        if [[ ${#input} -gt 255 ]]; then
            error "Path too long: $input"
        fi
        ;;
    "version")
        # Validate version format (x.y.z)
        if [[ ! "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            error "Invalid version format: $input"
        fi
        ;;
    esac
}

# Extract version from package
extract_version_from_package() {
    local archive="whph-linux-$ARCH.tar.gz"

    if [[ ! -f "$archive" ]]; then
        return 1
    fi

    # Try to extract pubspec.yaml from the archive and read version
    local version_line
    version_line=$(tar -tf "$archive" 2>/dev/null | grep "pubspec.yaml$" | head -1)
    if [[ -n "$version_line" ]]; then
        # Extract pubspec.yaml to temporary location and read version
        local temp_dir
        temp_dir=$(mktemp -d)
        tar -xzf "$archive" -C "$temp_dir" "*/pubspec.yaml" 2>/dev/null || {
            rm -rf "$temp_dir"
            return 1
        }

        # Find the pubspec.yaml file
        local pubspec_file
        pubspec_file=$(find "$temp_dir" -name "pubspec.yaml" | head -1)
        if [[ -f "$pubspec_file" ]]; then
            local extracted_version
            extracted_version=$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$pubspec_file" 2>/dev/null)
            rm -rf "$temp_dir"
            echo "$extracted_version"
            return 0
        fi

        rm -rf "$temp_dir"
    fi

    # Fallback: try to extract version from archive name (for backward compatibility)
    if [[ "$archive" =~ whph-linux-[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo "$archive" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+'
        return 0
    fi

    return 1
}

# Secure file extraction
secure_extract() {
    local archive="$1"
    local destination="$2"

    # Validate inputs
    validate_input "$archive" "path"
    validate_input "$destination" "path"

    # Check file type
    if ! file "$archive" | grep -q "gzip compressed"; then
        error "Invalid archive format: $archive"
    fi

    # Extract with security options
    tar -xzf "$archive" -C "$destination" --strip-components=1 \
        --no-same-owner --no-same-permissions
}

WHPH_INSTALL_DIR="${WHPH_INSTALL_DIR:-/opt/whph}"
WHPH_VERSION="${WHPH_VERSION:-}"
ARCH="$(uname -m)"

# Extract version from package if not specified
if [[ -z "$WHPH_VERSION" ]]; then
    WHPH_VERSION=$(extract_version_from_package)
    if [[ -z "$WHPH_VERSION" ]]; then
        error "Could not determine WHPH version. Please specify with WHPH_VERSION environment variable."
    fi
    log "Detected WHPH version: $WHPH_VERSION"
fi

# Validate environment variables
validate_input "$WHPH_INSTALL_DIR" "path"
validate_input "$WHPH_VERSION" "version"

# System requirements validation
validate_system() {
    log "Validating system requirements..."

    # Check distribution
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect Linux distribution"
    fi

    source /etc/os-release
    log "Detected distribution: $PRETTY_NAME"

    # Validate dependencies
    local missing_deps=()

    # Check for actual executables and libraries
    if ! command -v "notify-send" >/dev/null 2>&1; then
        missing_deps+=("libnotify (notify-send command)")
    fi

    if ! command -v "sqlite3" >/dev/null 2>&1; then
        missing_deps+=("sqlite3")
    fi

    # Check for GTK3 using pkg-config if available, otherwise check for gtk-launch
    if command -v "pkg-config" >/dev/null 2>&1; then
        if ! pkg-config --exists "gtk+-3.0" 2>/dev/null; then
            missing_deps+=("gtk3 (GTK+ 3.0 development libraries)")
        fi
    elif ! command -v "gtk-launch" >/dev/null 2>&1; then
        missing_deps+=("gtk3 (GTK+ 3.0 libraries)")
    fi

    # Check for appindicator using pkg-config
    if command -v "pkg-config" >/dev/null 2>&1; then
        if ! pkg-config --exists "ayatana-appindicator3-0.1" 2>/dev/null; then
            missing_deps+=("libayatana-appindicator (Ayatana AppIndicator library)")
        fi
    fi

    # Report missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}"
    fi
}

# Installation with proper permissions
install_whph() {
    log "Installing WHPH to $WHPH_INSTALL_DIR..."

    # Validate installation directory path
    if [[ "$WHPH_INSTALL_DIR" != "/opt/whph" && "$WHPH_INSTALL_DIR" != "/usr/local/whph" ]]; then
        warn "Installing to non-standard directory: $WHPH_INSTALL_DIR"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled by user"
        fi
    fi

    # Create installation directory securely
    if ! sudo mkdir -p "$WHPH_INSTALL_DIR"; then
        error "Failed to create installation directory: $WHPH_INSTALL_DIR"
    fi

    # Set secure permissions
    sudo chown root:root "$WHPH_INSTALL_DIR" || error "Failed to set ownership"
    sudo chmod 755 "$WHPH_INSTALL_DIR" || error "Failed to set permissions"

    # Validate and extract application
    local archive="whph-linux-$ARCH.tar.gz"
    if [[ -f "$archive" ]]; then
        log "Extracting WHPH from $archive..."
        secure_extract "$archive" "$WHPH_INSTALL_DIR"
    else
        error "WHPH package not found: $archive"
    fi

    # Verify installation
    if [[ ! -f "$WHPH_INSTALL_DIR/whph" ]]; then
        error "Installation failed: binary not found"
    fi

    # Set proper permissions securely
    sudo chown -R root:root "$WHPH_INSTALL_DIR" || error "Failed to set file ownership"
    sudo chmod 755 "$WHPH_INSTALL_DIR/whph" || error "Failed to set executable permissions"

    # Set permissions for config files if they exist
    if [[ -f "$WHPH_INSTALL_DIR/share/applications/whph.desktop" ]]; then
        sudo chmod 644 "$WHPH_INSTALL_DIR/share/applications/whph.desktop"
    fi
}

# Desktop integration
setup_desktop_integration() {
    log "Setting up desktop integration..."

    # Install desktop file
    sudo install -D -m 644 "$WHPH_INSTALL_DIR/share/applications/whph.desktop" \
        /usr/share/applications/whph.desktop

    # Install icons
    sudo install -D -m 644 "$WHPH_INSTALL_DIR/share/icons/hicolor/512x512/apps/whph.png" \
        /usr/share/icons/hicolor/512x512/apps/whph.png

    # Install D-Bus service
    sudo install -D -m 644 "$WHPH_INSTALL_DIR/share/dbus-1/services/me.ahmetcetinkaya.whph.service" \
        /usr/share/dbus-1/services/me.ahmetcetinkaya.whph.service

    # Install MIME type
    sudo install -D -m 644 "$WHPH_INSTALL_DIR/share/mime/packages/whph.xml" \
        /usr/share/mime/packages/whph.xml

    # Update system databases
    log "Updating system databases..."
    sudo update-desktop-database -q /usr/share/applications || warn "Failed to update desktop database"
    sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor || warn "Failed to update icon cache"
    sudo update-mime-database -n /usr/share/mime || warn "Failed to update MIME database"

    # Reload D-Bus services
    systemctl --user daemon-reload || warn "Failed to reload user D-Bus services"
}

# Create command-line symlink
setup_command_line() {
    log "Setting up command-line access..."

    if [[ -L /usr/local/bin/whph ]]; then
        sudo rm /usr/local/bin/whph
    fi

    sudo ln -s "$WHPH_INSTALL_DIR/whph" /usr/local/bin/whph
    log "Command-line access available via 'whph'"
}

# Main installation flow
main() {
    log "Starting WHPH installation..."

    validate_system
    install_whph
    setup_desktop_integration
    setup_command_line

    log "WHPH installation completed successfully!"
    log "Launch WHPH from your application menu or run 'whph' in terminal"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
