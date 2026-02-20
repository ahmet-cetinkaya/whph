#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

PUBSPEC_FILE="$PROJECT_ROOT/src/pubspec.yaml"

# Extract current version
CURRENT_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | sed 's/+.*//')

# Get current date in ISO format (YYYY-MM-DD)
CURRENT_DATE=$(date +%Y-%m-%d)

acore_log_header "Flathub Package Update"
FLATHUB_DIR="$PROJECT_ROOT/packaging/flatpak/flathub"

if [ ! -d "$FLATHUB_DIR" ]; then
    acore_log_error "Flathub directory not found at $FLATHUB_DIR"
    exit 1
fi

acore_log_info "Updating Flathub package at $FLATHUB_DIR..."
cd "$FLATHUB_DIR"

METAINFO_FILE="$FLATHUB_DIR/me.ahmetcetinkaya.whph.metainfo.xml"

if [ ! -f "$METAINFO_FILE" ]; then
    acore_log_error "Metainfo file not found at $METAINFO_FILE"
    exit 1
fi

acore_log_info "Adding release v$CURRENT_VERSION ($CURRENT_DATE) to metainfo.xml..."

# Check if the release already exists
if grep -q "version=\"$CURRENT_VERSION\"" "$METAINFO_FILE"; then
    acore_log_info "Release v$CURRENT_VERSION already exists in metainfo.xml"
else
    # Use sed to insert the new release entry after the <releases> tag
    # The new entry should be the first (most recent) release
    sed -i "s|<releases>|<releases>\n    <release version=\"$CURRENT_VERSION\" date=\"$CURRENT_DATE\" />|" "$METAINFO_FILE"
    acore_log_success "Added release v$CURRENT_VERSION ($CURRENT_DATE) to metainfo.xml"
fi

acore_log_success "Flathub metainfo updated successfully."
