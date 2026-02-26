#!/bin/bash

# Package Flatpak script (New Structure - Clean Flathub Output)
# Usage: ./scripts/package_flatpak.sh

set -e

CI_MODE=false
LOCAL_MODE=false
FLATHUB_MODE=false
for arg in "$@"; do
    if [[ "$arg" == "--ci" ]]; then
        CI_MODE=true
    elif [[ "$arg" == "--local" ]]; then
        LOCAL_MODE=true
    elif [[ "$arg" == "--flathub" ]]; then
        FLATHUB_MODE=true
    fi
done

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

# Get project root and packaging directories
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FLATPAK_DIR="$PROJECT_ROOT/packaging/flatpak"
FLATHUB_DIR="$FLATPAK_DIR/flathub"
FLATPAK_FLUTTER_PY="$FLATPAK_DIR/flatpak-flutter/flatpak-flutter.py"
VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python3"
VERSION=$(grep "^version:" "$PROJECT_ROOT/src/pubspec.yaml" | sed 's/version: //' | sed 's/+.*//')

acore_log_header "FLATPAK PACKAGING (v$VERSION)"

# Check dependencies
for cmd in flatpak-builder flatpak python3; do
    if ! command -v "$cmd" &>/dev/null; then
        acore_log_error "\"$cmd\" is not installed. Please install it first."
        exit 1
    fi
done

# 1. Regenerate Manifest
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

# Clean up stale generator build directories to avoid "already exists" errors
rm -rf "$FLATPAK_DIR/.flatpak-builder/build/whph"*

# Change to FLATPAK_DIR so .flatpak-builder ends up there
cd "$FLATPAK_DIR"

INPUT_MANIFEST="flatpak-flutter.yaml"
if [[ "$LOCAL_MODE" == true || "$CI_MODE" == true ]]; then
    acore_log_info "Local or CI mode enabled. Using current directory as source."
    acore_log_warning "Local/CI mode builds locally but flathub files will use git source for submission."
fi

# Run generator. This creates me.ahmetcetinkaya.whph.yaml and generated/ in CWD.
# --app-pubspec is relative to the SOURCE root (the git repo), not the CWD.
if "$VENV_PYTHON" "$FLATPAK_FLUTTER_PY" --app-pubspec src "$INPUT_MANIFEST"; then
    # Move generation results to FLATHUB_DIR
    acore_log_info "Moving generated files to flathub submodule..."
    MANIFEST_NAME="me.ahmetcetinkaya.whph.yaml"
    mv "$MANIFEST_NAME" "$FLATHUB_DIR/"
    rm -rf "$FLATHUB_DIR/generated"
    mv "generated" "$FLATHUB_DIR/"
else
    if [[ "$LOCAL_MODE" == true && -f "$FLATHUB_DIR/me.ahmetcetinkaya.whph.yaml" ]]; then
        acore_log_warning "Manifest generation failed (likely offline). Using existing manifest for local build."
        MANIFEST_NAME="me.ahmetcetinkaya.whph.yaml"
    else
        acore_log_error "Manifest generation failed."
        exit 1
    fi
fi

if [[ "$FLATHUB_MODE" == true ]]; then
    acore_log_info "Flathub mode enabled. Applying Flathub specific restrictions..."
    acore_log_info "Removing --talk-name=org.freedesktop.Flatpak for Flathub compliance. Refer to docs/packaging/FLATPAK_PACKAGING.md"
    
    $VENV_PYTHON -c "
import yaml
manifest_path = '$FLATHUB_DIR/$MANIFEST_NAME'
with open(manifest_path, 'r') as f:
    manifest = yaml.safe_load(f)

if 'finish-args' in manifest:
    manifest['finish-args'] = [arg for arg in manifest['finish-args'] if arg != '--talk-name=org.freedesktop.Flatpak']

for module in manifest.get('modules', []):
    if isinstance(module, dict) and module.get('name') == 'whph':
        if 'build-commands' in module:
            new_cmds = []
            for cmd in module['build-commands']:
                if 'flutter build linux' in cmd:
                    new_cmds.append(cmd + ' --dart-define=FLATHUB=true')
                else:
                    new_cmds.append(cmd)
            module['build-commands'] = new_cmds
        break

with open(manifest_path, 'w') as f:
    yaml.dump(manifest, f, sort_keys=False)
"
fi

# Format output files with prettier for Flathub submission
acore_log_info "Formatting output files with prettier..."

cd "$PROJECT_ROOT"

# Format YAML manifest
if bunx prettier --write "$FLATHUB_DIR/$MANIFEST_NAME" 2>&1; then
    acore_log_success "YAML manifest formatted."
else
    acore_log_warning "prettier not found. Please install it with: bun add -g prettier"
fi

# Format metainfo XML (Requires @prettier/plugin-xml)
if bunx prettier --plugin=@prettier/plugin-xml --write "$PROJECT_ROOT/src/linux/share/metainfo/me.ahmetcetinkaya.whph.metainfo.xml" 2>/dev/null; then
    acore_log_success "Metainfo XML formatted."
elif bunx prettier --write "$PROJECT_ROOT/src/linux/share/metainfo/me.ahmetcetinkaya.whph.metainfo.xml" 2>/dev/null; then
    acore_log_success "Metainfo XML formatted."
else
    acore_log_warning "Could not format XML. For XML formatting, install: bun add -g prettier @prettier/plugin-xml"
fi

# Vendor Shared Modules

# 2. Build Flatpak
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

BUILD_MANIFEST="$MANIFEST_NAME"
if [[ "$LOCAL_MODE" == true || "$CI_MODE" == true ]]; then
    acore_log_info "Local/CI mode: Creating shadow manifest for build using local directory source..."
    BUILD_MANIFEST="me.ahmetcetinkaya.whph.local.yaml"
    cp "flathub/$MANIFEST_NAME" "flathub/$BUILD_MANIFEST"
    
    # Replace the git source with a directory source in the local manifest
    $VENV_PYTHON -c "
import yaml
import os
manifest_path = 'flathub/$BUILD_MANIFEST'
with open(manifest_path, 'r') as f:
    manifest = yaml.safe_load(f)
for module in manifest.get('modules', []):
    if isinstance(module, dict) and module.get('name') == 'whph':
        whph_sources = module.get('sources', [])
        new_sources = [{'type': 'dir', 'path': '../../../'}]
        # When script runs this, it is in FLATPAK_DIR (packaging/flatpak)
        PROJECT_ROOT_FOR_CHECK = '../../'
        for source in whph_sources:
            if not isinstance(source, dict):
                new_sources.append(source)
                continue
            if source.get('type') == 'git':
                dest = source.get('dest')
                url = source.get('url')
                if url == 'https://github.com/ahmet-cetinkaya/whph.git':
                    continue
                if dest and os.path.exists(os.path.join(PROJECT_ROOT_FOR_CHECK, dest)):
                    continue
            new_sources.append(source)
        module['sources'] = new_sources
        break
with open(manifest_path, 'w') as f:
    yaml.dump(manifest, f, sort_keys=False)
"
fi

BUILDER_ARGS=("--force-clean" "--user" "--install" "--install-deps-from=flathub" "--repo=$REPO_DIR")
if [[ "$CI_MODE" == true || "$CI" == "true" ]]; then
    acore_log_info "CI mode detected. Disabling rofiles-fuse..."
    BUILDER_ARGS+=("--disable-rofiles-fuse")
fi

flatpak-builder "${BUILDER_ARGS[@]}" "$BUILD_DIR" "flathub/$BUILD_MANIFEST"

# Clean up shadow manifest after build
if [[ ("$LOCAL_MODE" == true || "$CI_MODE" == true) && -f "flathub/$BUILD_MANIFEST" ]]; then
    rm "flathub/$BUILD_MANIFEST"
fi

# 3. Create Bundle
acore_log_section "🎁  Creating Flatpak Bundle..."
BUNDLE_NAME="$PROJECT_ROOT/whph-v$VERSION-linux.flatpak"
flatpak build-bundle "$REPO_DIR" "$BUNDLE_NAME" me.ahmetcetinkaya.whph master

acore_log_success "✅  Flatpak packaging complete!"
acore_log_info "Flathub submodule updated: $FLATHUB_DIR"
acore_log_info "Build cache located in: $FLATPAK_DIR/.flatpak-builder"
acore_log_info "Bundle created: $BUNDLE_NAME"
acore_log_info "To install from bundle: flatpak install --user $BUNDLE_NAME"
acore_log_info "To run: flatpak run me.ahmetcetinkaya.whph"
