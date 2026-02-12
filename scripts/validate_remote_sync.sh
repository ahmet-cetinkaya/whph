#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"
SRC_DIR="$PROJECT_ROOT/src"

acore_log_header "Remote Sync Validation"

acore_log_info "Please ensure WHPH is running separately."
acore_log_info "If not, start it with: fvm flutter run -d linux"
read -rp "Press Enter when app is running..."

acore_log_info "Triggering sync..."

cd "$PROJECT_ROOT" || exit 1
acore_log_section "Building Linux debug bundle"
fvm flutter build linux --debug --project-directory "$SRC_DIR"

acore_log_info "Running trigger..."
"$SRC_DIR/build/linux/x64/debug/bundle/whph" --sync

acore_log_success "Done. Check the logs of the MAIN app instance."
