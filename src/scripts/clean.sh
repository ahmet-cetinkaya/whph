#!/usr/bin/env bash
set -e

trap 'echo "> ❌ Clean failed!"; exit 1' ERR

# Get the directory of the script and navigate to src directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(dirname "$SCRIPT_DIR")"
cd "$SRC_DIR"

# Clean Flutter build artifacts
echo "> 🧹 Cleaning Flutter build..."
fvm flutter clean

# Remove all contents of android/fdroid/build except extlib
echo "> 🗑️  Cleaning android/fdroid/build except extlib..."
if [ -d "android/fdroid/build" ]; then
    # Use a more robust approach to clean the directory
    for item in android/fdroid/build/*; do
        if [ -e "$item" ] && [ "$(basename "$item")" != "extlib" ]; then
            echo "  Removing: $(basename "$item")"
            rm -rf "$item" 2>/dev/null || true
        fi
    done
fi

# Remove pub cache
echo "> 🗄️  Removing pub cache..."
if [ -d ~/.pub-cache/hosted/pub.dev ]; then
    rm -rf ~/.pub-cache/hosted/pub.dev/* 2>/dev/null || true
fi

# Remove .dart_tool
echo "> 🗂️  Removing .dart_tool..."
if [ -d .dart_tool ]; then
    rm -rf .dart_tool
fi

# Repair and get pub packages
echo "> 🔧 Repairing and fetching pub packages..."
fvm flutter pub cache repair || echo "  ⚠️  Warning: pub cache repair failed, continuing..."
fvm flutter pub get

echo "> ✅ Clean completed."
