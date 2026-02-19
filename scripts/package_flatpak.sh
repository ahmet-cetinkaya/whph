#!/bin/bash

# Package Flatpak script (New Structure - Clean Flathub Output)
# Usage: ./scripts/package_flatpak.sh

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

# Get project root and packaging directories
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FLATPAK_DIR="$PROJECT_ROOT/packaging/flatpak"
FLATHUB_DIR="$FLATPAK_DIR/flathub"
FLATPAK_FLUTTER_PY="$FLATPAK_DIR/flatpak-flutter/flatpak-flutter.py"
VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python3"

acore_log_header "FLATPAK PACKAGING (CLEAN FLATHUB OUTPUT)"

# Check dependencies
for cmd in flatpak-builder flatpak python3; do
    if ! command -v "$cmd" &>/dev/null; then
        acore_log_error "\"$cmd\" is not installed. Please install it first."
        exit 1
    fi
done

# 1. Verify Icon
acore_log_section "🎨  Verifying Icons..."
ICON_SRC="$PROJECT_ROOT/src/lib/core/domain/shared/assets/images/whph-512.png"

if [[ ! -f "$ICON_SRC" ]]; then
    acore_log_error "Icon not found at $ICON_SRC. Please ensure it exists."
    exit 1
fi
acore_log_info "Icon found at $ICON_SRC"

# 2. Regenerate Manifest
acore_log_section "📝  Regenerating Flatpak Manifest..."
if [[ ! -f "$VENV_PYTHON" ]]; then
    acore_log_warning "Virtual environment not found at $VENV_PYTHON."
    acore_log_info "Checking if system python3 has required packages..."
    
    if python3 -c "import yaml, tomlkit, packaging" 2>/dev/null; then
        acore_log_success "✅ System python3 has required packages. Proceeding with system python3."
        VENV_PYTHON="python3"
    else
        acore_log_error "Required Python packages (PyYAML, tomlkit, packaging) not found. Please run setup first or ensure they are installed in system python3."
        exit 1
    fi
fi

if [[ ! -f "$FLATPAK_FLUTTER_PY" ]]; then
    acore_log_error "flatpak-flutter.py not found at $FLATPAK_FLUTTER_PY. Did you initialize submodules?"
    exit 1
fi

# Change to FLATPAK_DIR so .flatpak-builder ends up there
cd "$FLATPAK_DIR"

# Run generator. This creates me.ahmetcetinkaya.whph.yaml and generated/ in CWD.
# --app-pubspec is relative to the SOURCE root (the git repo), not the CWD.
"$VENV_PYTHON" "$FLATPAK_FLUTTER_PY" --app-pubspec src flatpak-flutter.yaml

# Move generation results to FLATHUB_DIR
acore_log_info "Moving generated files to flathub submodule..."
MANIFEST_NAME="me.ahmetcetinkaya.whph.yaml"
mv "$MANIFEST_NAME" "$FLATHUB_DIR/"
rm -rf "$FLATHUB_DIR/generated"
mv "generated" "$FLATHUB_DIR/"

# Vendor Shared Modules

# 3. Build Flatpak
acore_log_section "🏗️  Building Flatpak..."
acore_log_info "Cleaning host build artifacts..."
rm -rf "$PROJECT_ROOT/src/build"

BUILD_DIR="$PROJECT_ROOT/build-dir"
REPO_DIR="$PROJECT_ROOT/repo"

# Ensure repo is valid (flatpak-builder fails if config is missing)
if [[ -d "$REPO_DIR" && ! -f "$REPO_DIR/config" ]]; then
    acore_log_warning "Repo directory exists but is missing config. Removing corrupted repo..."
    rm -rf "$REPO_DIR"
fi

# Ensure Flathub remote exists for dependencies
acore_log_info "Ensuring Flathub remote exists..."
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Build from the FLATPAK_DIR to keep .flatpak-builder there
cd "$FLATPAK_DIR"
flatpak-builder --force-clean --user --install --install-deps-from=flathub --repo="$REPO_DIR" "$BUILD_DIR" "flathub/$MANIFEST_NAME"

# 4. Create Bundle
acore_log_section "🎁  Creating Flatpak Bundle..."
BUNDLE_NAME="$PROJECT_ROOT/whph.flatpak"
flatpak build-bundle "$REPO_DIR" "$BUNDLE_NAME" me.ahmetcetinkaya.whph master

acore_log_success "✅  Flatpak packaging complete!"
acore_log_info "Flathub submodule updated: $FLATHUB_DIR"
acore_log_info "Build cache located in: $FLATPAK_DIR/.flatpak-builder"
acore_log_info "Bundle created: $BUNDLE_NAME"
acore_log_info "To install from bundle: flatpak install --user $BUNDLE_NAME"
acore_log_info "To run: flatpak run me.ahmetcetinkaya.whph"
