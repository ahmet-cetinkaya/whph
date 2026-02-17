#!/bin/bash

# Script to update the Nix flake with the latest version and hash
# Similar to update_aur.sh but for Nix packaging

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load logger
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

PUBSPEC_FILE="$PROJECT_ROOT/src/pubspec.yaml"
NIX_DIR="$PROJECT_ROOT/packaging/nix"
FLAKE_FILE="$NIX_DIR/flake.nix"

# Extract current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | sed 's/+.*//')

acore_log_header "Nix Package Update"
acore_log_info "Updating Nix package for version v$CURRENT_VERSION..."

if [ ! -d "$NIX_DIR" ]; then
    acore_log_error "Nix directory not found at $NIX_DIR"
    exit 1
fi

# Update version in flake.nix
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/version = \".*\";/version = \"$CURRENT_VERSION\";/" "$FLAKE_FILE"
else
    sed -i "s/version = \".*\";/version = \"$CURRENT_VERSION\";/" "$FLAKE_FILE"
fi

# Get the SHA256 hash of the new release artifact
ARTIFACT_URL="https://github.com/ahmet-cetinkaya/whph/releases/download/v$CURRENT_VERSION/whph-v$CURRENT_VERSION-linux.tar.gz"
acore_log_info "Fetching SRI hash for $ARTIFACT_URL..."

# Prefetch with nix if available, otherwise fallback to curl + sha256sum
NEW_HASH=""
if command -v nix-prefetch-url &>/dev/null; then
    NEW_HASH=$(nix-prefetch-url --type sha256 --unpack "$ARTIFACT_URL" 2>/dev/null || true)
fi

if [ -z "$NEW_HASH" ]; then
    acore_log_info "Calculating hash via curl and sha256sum..."
    TEMP_FILE=$(mktemp)
    if curl -L -s "$ARTIFACT_URL" -o "$TEMP_FILE"; then
        RAW_HASH=$(sha256sum "$TEMP_FILE" | cut -d' ' -f1)
        NEW_HASH="sha256-$(echo "$RAW_HASH" | xxd -r -p | base64)"
        rm "$TEMP_FILE"
    else
        acore_log_error "Failed to download artifact: $ARTIFACT_URL"
        rm "$TEMP_FILE"
        exit 1
    fi
fi

acore_log_info "New hash: $NEW_HASH"

# Update hash in flake.nix
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|hash = \"sha256-.*\";|hash = \"$NEW_HASH\";|g" "$FLAKE_FILE"
else
    sed -i "s|hash = \"sha256-.*\";|hash = \"$NEW_HASH\";|g" "$FLAKE_FILE"
fi

# Update flake.lock if nix is available
if command -v nix &>/dev/null; then
    acore_log_info "Updating flake.lock..."
    cd "$NIX_DIR"
    nix flake update --extra-experimental-features "nix-command flakes"
    cd "$PROJECT_ROOT"
fi

# Git operations
acore_log_info "Staging changes..."
git add "$FLAKE_FILE" "$NIX_DIR/flake.lock"

if [[ -z $(git status -s "$FLAKE_FILE" "$NIX_DIR/flake.lock") ]]; then
    acore_log_info "No changes to commit."
else
    acore_log_info "Committing and pushing..."
    git commit -m "chore(nix): bump version to v$CURRENT_VERSION"
    git push
fi

acore_log_success "Nix package updated successfully."
