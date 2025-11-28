#!/bin/bash
set -euo pipefail

WHPH_INSTALL_DIR="${WHPH_INSTALL_DIR:-/opt/whph}"
WHPH_VERSION="${WHPH_VERSION:-0.18.0}"
ARCH="$(uname -m)"

# Logging and error handling
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
    exit 1
}
warn() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*"; }

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
    local deps=("gtk3" "libayatana-appindicator" "libnotify" "sqlite3")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            warn "$dep not found, please install required dependencies"
        fi
    done
}

# Installation with proper permissions
install_whph() {
    log "Installing WHPH to $WHPH_INSTALL_DIR..."

    # Create installation directory
    sudo mkdir -p "$WHPH_INSTALL_DIR"
    sudo chown root:root "$WHPH_INSTALL_DIR"
    sudo chmod 755 "$WHPH_INSTALL_DIR"

    # Extract and install application
    if [[ -f "whph-linux-$ARCH.tar.gz" ]]; then
        sudo tar -xzf "whph-linux-$ARCH.tar.gz" -C "$WHPH_INSTALL_DIR" --strip-components=1
    else
        error "WHPH package not found: whph-linux-$ARCH.tar.gz"
    fi

    # Set proper permissions
    sudo chown -R root:root "$WHPH_INSTALL_DIR"
    sudo chmod 755 "$WHPH_INSTALL_DIR/whph"
    sudo chmod 644 "$WHPH_INSTALL_DIR/share/applications/whph.desktop"
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
