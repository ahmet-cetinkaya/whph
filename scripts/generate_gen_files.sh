#!/usr/bin/env bash

# Source acore logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
cd "$SRC_DIR"

acore_log_info "Cleaning build_runner cache..."
fvm flutter pub run build_runner clean

acore_log_info "Running generated files..."
fvm flutter pub run build_runner build --delete-conflicting-outputs

acore_log_info "Generating drift schema helper files for testing..."
fvm dart run drift_dev schema generate lib/infrastructure/persistence/shared/contexts/drift/schemas/app_database/ test/drift/app_database/generated

acore_log_success "Code generation completed successfully!"
