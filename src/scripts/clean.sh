#!/usr/bin/env bash
set -e

# Source acore logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../packages/acore-scripts/src/logger.sh"

trap 'acore_log_error "Clean failed!"; exit 1' ERR

SRC_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$SRC_DIR")"
cd "$SRC_DIR"

# Clean Flutter build artifacts
acore_log_info "Cleaning Flutter build..."
fvm flutter clean

# Clean Flatpak build artifacts
acore_log_info "Cleaning Flatpak build artifacts..."
rm -rf "$PROJECT_ROOT/.flatpak-builder"
rm -rf "$PROJECT_ROOT/packaging/flatpak/.flatpak-builder"
rm -rf "$PROJECT_ROOT/build-dir"
rm -rf "$PROJECT_ROOT/repo"
rm -f "$PROJECT_ROOT/whph.flatpak"

# Remove all contents of android/fdroid/build except extlib
acore_log_info "Cleaning android/fdroid/build except extlib..."
if [ -d "android/fdroid/build" ]; then
	# Use a more robust approach to clean the directory
	for item in android/fdroid/build/*; do
		if [ -e "$item" ] && [ "$(basename "$item")" != "extlib" ]; then
			acore_log_info "Removing: $(basename "$item")"
			rm -rf "$item" 2>/dev/null || true
		fi
	done
fi

# Remove generated files
acore_log_info "Removing generated files (*.g.dart, *.mocks.dart)..."
fd -e "g.dart" -t f . . 2>/dev/null | xargs rm -f
fd -e "mocks.dart" -t f . . 2>/dev/null | xargs rm -f

# Remove drift generated schema files
acore_log_info "Removing drift generated schema files..."
if [ -d "test/drift/app_database/generated" ]; then
	rm -rf test/drift/app_database/generated/*
fi

# Remove pub cache
acore_log_info "Removing pub cache..."
if [ -d ~/.pub-cache/hosted/pub.dev ]; then
	rm -rf ~/.pub-cache/hosted/pub.dev/* 2>/dev/null || true
fi

# Remove .dart_tool
acore_log_info "Removing .dart_tool..."
if [ -d .dart_tool ]; then
	rm -rf .dart_tool
fi

# Repair and get pub packages
acore_log_info "Repairing and fetching pub packages..."
fvm flutter pub cache repair || acore_log_warning "pub cache repair failed, continuing..."
fvm flutter pub get

# Run code generation
acore_log_info "Running code generation (rps gen)..."
bash scripts/generate_gen_files.sh

acore_log_success "Clean and generation completed."
