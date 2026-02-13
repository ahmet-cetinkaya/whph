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

SKIP_BUILD=false
for arg in "$@"; do
    case $arg in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
    esac
done

# Check dependencies
# Check dependencies
for cmd in flatpak-builder flatpak; do
    if ! command -v "$cmd" &>/dev/null; then
        acore_log_error "\"$cmd\" is not installed. Please install it first."
        exit 1
    fi
done

# 1. Build Flutter Linux Release
if [[ "$SKIP_BUILD" == "false" ]]; then
    acore_log_section "🏗️  Building Flutter Linux Release..."
    cd "$SRC_DIR"
    fvm flutter build linux --release
else
    acore_log_section "⏭️  Skipping Flutter Build (--skip-build)..."
fi

# 1.5 Post-process Build Artifacts
acore_log_section "🔧  Post-processing Build Artifacts..."
BUNDLE_DIR="$SRC_DIR/build/linux/x64/release/bundle"
DESKTOP_FILE="$BUNDLE_DIR/share/applications/whph.desktop"
ICON_FILE="$BUNDLE_DIR/share/icons/hicolor/512x512/apps/whph.png"

# Resize icon to standard Flathub sizes (64, 128, 512)
if [[ -f "$ICON_FILE" ]]; then
    acore_log_info "Generating standard icon sizes (64, 128, 512)..."
    
    # Define sizes
    SIZES=(64 128 512)
    
    # Determine resize tool
    RESIZE_CMD=""
    if command -v magick &>/dev/null; then
        RESIZE_CMD="magick"
    elif command -v convert &>/dev/null; then
        RESIZE_CMD="convert"
    else
        acore_log_warning "ImageMagick not found. Skipping icon resizing."
    fi

    if [[ -n "$RESIZE_CMD" ]]; then
        for size in "${SIZES[@]}"; do
            SIZE_DIR="$BUNDLE_DIR/share/icons/hicolor/${size}x${size}/apps"
            mkdir -p "$SIZE_DIR"
            TARGET_FILE="$SIZE_DIR/whph.png"
            
            acore_log_info "Generating ${size}x${size} icon..."
            "$RESIZE_CMD" "$ICON_FILE" -resize "${size}x${size}!" "$TARGET_FILE" || acore_log_warning "Failed to resize icon to ${size}x${size}."
        done
    fi
fi

# Patch Desktop File
if [[ -f "$DESKTOP_FILE" ]]; then
    acore_log_info "Patching desktop file for Flatpak..."
    # Fix Exec path, Icon name, Version, and Categories in one go
    sed -i \
        -e 's|^Exec=.*|Exec=whph %U|' \
        -e 's|^Icon=.*|Icon=me.ahmetcetinkaya.whph|' \
        -e 's|^Version=.*|Version=1.0|' \
        -e 's|^Categories=.*|Categories=Utility;Office;|' \
        "$DESKTOP_FILE"
fi

# Resize and Rename Dynamic Tray Icons
TRAY_ICON_SRC="$SRC_DIR/lib/core/domain/shared/assets/images"
TARGET_ICON_DIR="$BUNDLE_DIR/share/icons/hicolor/512x512/apps"

if [[ -d "$TRAY_ICON_SRC" ]]; then
    acore_log_info "Processing dynamic tray icons..."

    # Process Play Icon
    if [[ -f "$TRAY_ICON_SRC/whph_logo_fg_play.png" ]]; then
        cp "$TRAY_ICON_SRC/whph_logo_fg_play.png" "$TARGET_ICON_DIR/me.ahmetcetinkaya.whph.play.png"
    fi

    # Process Pause Icon
    if [[ -f "$TRAY_ICON_SRC/whph_logo_fg_pause.png" ]]; then
        cp "$TRAY_ICON_SRC/whph_logo_fg_pause.png" "$TARGET_ICON_DIR/me.ahmetcetinkaya.whph.pause.png"
    fi

    # Process Default Adaptive Icon
    if [[ -f "$TRAY_ICON_SRC/whph_logo_fg.png" ]]; then
        cp "$TRAY_ICON_SRC/whph_logo_fg.png" "$TARGET_ICON_DIR/me.ahmetcetinkaya.whph.default.png"
    fi
fi

# Patch Service File
    SERVICE_FILE="$BUNDLE_DIR/share/dbus-1/services/whph.service"
    if [[ -f "$SERVICE_FILE" ]]; then
        acore_log_info "Patching service file for Flatpak..."
        sed -i 's|^Exec=.*|Exec=/app/bin/whph|' "$SERVICE_FILE"
fi

# 2. Build Flatpak
acore_log_section "📦  Building Flatpak..."
cd "$PROJECT_ROOT"

# Ensure Flathub remote exists (needed for runtime/sdk)
acore_log_info "Ensuring Flathub remote exists..."
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || acore_log_warning "Failed to add flathub remote (might already exist or network issue)."

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
# --install-deps-from=flathub: Automatically install missing runtime/sdk from flathub
flatpak-builder --force-clean --user --install --install-deps-from=flathub --repo="$REPO_DIR" "$BUILD_DIR" "$MANIFEST_PATH"

# 3. Create Bundle
acore_log_section "🎁  Creating Flatpak Bundle..."
flatpak build-bundle "$REPO_DIR" whph.flatpak me.ahmetcetinkaya.whph

acore_log_success "✅  Flatpak packaging complete! Bundle created: whph.flatpak"
acore_log_info "To install locally: flatpak install --user --bundle whph.flatpak"
acore_log_info "To run: flatpak run me.ahmetcetinkaya.whph"
