#!/bin/bash

# Package Flatpak script
# Usage: ./scripts/package_flatpak.sh

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

# Get project root and src directory
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"

acore_log_header "FLATPAK PACKAGING"

# Check dependencies
if ! command -v flatpak-builder &> /dev/null; then
    acore_log_error "flatpak-builder is not installed. Please install it first."
    exit 1
fi

if ! command -v flatpak &> /dev/null; then
    acore_log_error "flatpak is not installed. Please install it first."
    exit 1
fi

# 1. Build Flutter Linux Release
acore_log_section "🏗️  Building Flutter Linux Release..."
cd "$SRC_DIR"
fvm flutter build linux --release

# 1.5 Post-process Build Artifacts
acore_log_section "🔧  Post-processing Build Artifacts..."
BUNDLE_DIR="$SRC_DIR/build/linux/x64/release/bundle"
DESKTOP_FILE="$BUNDLE_DIR/share/applications/whph.desktop"
ICON_FILE="$BUNDLE_DIR/share/icons/hicolor/512x512/apps/whph.png"

# Resize icon to 512x512 if it exists and is larger
if [[ -f "$ICON_FILE" ]]; then
    acore_log_info "Check/Resizing icon to 512x512..."
    if command -v magick &> /dev/null; then
        magick "$ICON_FILE" -resize 512x512! "$ICON_FILE" || acore_log_warning "Failed to resize icon."
    elif command -v convert &> /dev/null; then
        convert "$ICON_FILE" -resize 512x512! "$ICON_FILE" || acore_log_warning "Failed to resize icon."
    else
        acore_log_warning "ImageMagick not found. Skipping icon resizing."
    fi
fi

# Patch Desktop File
if [[ -f "$DESKTOP_FILE" ]]; then
    acore_log_info "Patching desktop file for Flatpak..."
    # Fix Exec path to just the command name
    sed -i 's|^Exec=.*|Exec=whph %U|' "$DESKTOP_FILE"
    # Fix Icon name to match App ID
    sed -i 's|^Icon=.*|Icon=me.ahmetcetinkaya.whph|' "$DESKTOP_FILE"
    # Fix Version to 1.0 (Desktop Entry Spec version)
    sed -i 's|^Version=.*|Version=1.0|' "$DESKTOP_FILE"
    # Fix Categories to standard ones (remove non-standard ones that cause validation errors)
    sed -i 's|^Categories=.*|Categories=Utility;Office;|' "$DESKTOP_FILE"
fi

# Patch Service File
SERVICE_FILE="$BUNDLE_DIR/share/dbus-1/services/whph.service"
if [[ -f "$SERVICE_FILE" ]]; then
    acore_log_info "Patching D-Bus service file for Flatpak..."
    sed -i 's|^Exec=.*|Exec=/app/bin/whph|' "$SERVICE_FILE"
fi

# 2. Build Flatpak
acore_log_section "📦  Building Flatpak..."
cd "$PROJECT_ROOT"

MANIFEST_PATH="src/linux/packaging/flatpak/me.ahmetcetinkaya.whph.yaml"
BUILD_DIR="build-dir"
REPO_DIR="repo"

# Ensure clean state
rm -rf "$BUILD_DIR"
rm -rf "$REPO_DIR"

# Ensure the build directory exists
mkdir -p "$BUILD_DIR"

# Build the application
# --force-clean: Clean the build directory before building
# --user: Install to the user installation
# --install: Install the application after building
flatpak-builder --force-clean --user --install --repo="$REPO_DIR" "$BUILD_DIR" "$MANIFEST_PATH"

# 3. Create Bundle
acore_log_section "🎁  Creating Flatpak Bundle..."
flatpak build-bundle "$REPO_DIR" whph.flatpak me.ahmetcetinkaya.whph

acore_log_success "✅  Flatpak packaging complete! Bundle created: whph.flatpak"
acore_log_info "To install locally: flatpak install --user --bundle whph.flatpak"
acore_log_info "To run: flatpak run me.ahmetcetinkaya.whph"
