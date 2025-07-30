#!/bin/bash

# WHPH Flatpak Build Script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLATPAK_DIR="$SCRIPT_DIR"
APP_ID="me.ahmetcetinkaya.whph"

echo "Building WHPH Flatpak..."
echo "Project root: $PROJECT_ROOT"
echo "Flatpak directory: $FLATPAK_DIR"

# Check if required tools are installed
if ! command -v flatpak &> /dev/null; then
    echo "Error: flatpak is not installed. Please install flatpak first."
    exit 1
fi

if ! command -v flatpak-builder &> /dev/null; then
    echo "Error: flatpak-builder is not installed. Please install flatpak-builder first."
    exit 1
fi

# Note: Flutter SDK will be downloaded and installed during the build process

# Ensure required runtimes are installed
echo "Ensuring required runtimes are installed..."
flatpak install -y --user flathub org.freedesktop.Platform//23.08
flatpak install -y --user flathub org.freedesktop.Sdk//23.08

# Clean any previous builds
echo "Cleaning previous builds..."
rm -rf "$FLATPAK_DIR/build-dir"
rm -rf "$FLATPAK_DIR/repo"
rm -f "$FLATPAK_DIR/$APP_ID.flatpak"

# Build the Flatpak
echo "Building Flatpak..."
cd "$FLATPAK_DIR"

flatpak-builder \
    --force-clean \
    --disable-rofiles-fuse \
    --user \
    --install-deps-from=flathub \
    build-dir \
    "$APP_ID.yml"

echo "Creating Flatpak bundle..."
flatpak build-export repo build-dir
flatpak build-bundle repo "$APP_ID.flatpak" "$APP_ID"

echo ""
echo "✅ Flatpak build completed successfully!"
echo "📦 Flatpak bundle created: $FLATPAK_DIR/$APP_ID.flatpak"
echo ""
echo "To install the Flatpak:"
echo "  flatpak install --user $APP_ID.flatpak"
echo ""
echo "To run the application:"
echo "  flatpak run $APP_ID"
echo ""
echo "To uninstall:"
echo "  flatpak uninstall --user $APP_ID"