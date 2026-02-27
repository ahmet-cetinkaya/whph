#!/usr/bin/env bash
set -e

# Source acore logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

trap 'acore_log_error "Clean failed!"; exit 1' ERR

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
cd "$SRC_DIR"

# Helper function to remove files/directories with sudo fallback
rmrf_or_try_with_sudo() {
    local target="$1"
    if [ -e "$target" ]; then
        if ! rm -rf "$target" 2>/dev/null; then
            acore_log_warning "Failed to remove $target, trying with sudo..."
            sudo rm -rf "$target" || acore_log_warning "Failed to remove $target even with sudo"
        fi
    fi
}

# Clean Flutter build artifacts
acore_log_info "Cleaning Flutter build..."

run_flutter_clean() {
    local exit_code
    set +e
    fvm flutter clean 2>&1
    exit_code=$?
    set -e
    return $exit_code
}

run_flutter_clean || true
CLEAN_EXIT=$?

if [ $CLEAN_EXIT -ne 0 ]; then
    acore_log_warning "flutter clean failed (exit code: $CLEAN_EXIT), attempting manual cleanup..."
    # Clean common Flutter directories that might have permission issues
    rmrf_or_try_with_sudo ".dart_tool"
    rmrf_or_try_with_sudo "build"
    rmrf_or_try_with_sudo "android/app/build"
    rmrf_or_try_with_sudo "ios/Pods"
    rmrf_or_try_with_sudo "ios/.symlinks"
    rmrf_or_try_with_sudo "linux/flutter/ephemeral"
    rmrf_or_try_with_sudo "windows/flutter/ephemeral"
    rmrf_or_try_with_sudo "linux/build"
    rmrf_or_try_with_sudo "macos/Pods"
    rmrf_or_try_with_sudo ".flutter-plugins"
    rmrf_or_try_with_sudo ".flutter-plugins-dependencies"
fi

# Clean Flatpak build artifacts
acore_log_info "Cleaning Flatpak build artifacts..."
rmrf_or_try_with_sudo "$PROJECT_ROOT/.flatpak-builder"
rmrf_or_try_with_sudo "$PROJECT_ROOT/packaging/flatpak/.flatpak-builder"
rmrf_or_try_with_sudo "$PROJECT_ROOT/build-dir"
rmrf_or_try_with_sudo "$PROJECT_ROOT/repo"
rm -f "$PROJECT_ROOT/whph.flatpak"

# Remove all contents of android/fdroid/build except extlib
acore_log_info "Cleaning android/fdroid/build except extlib..."
if [ -d "android/fdroid/build" ]; then
	# Use a more robust approach to clean the directory
	for item in android/fdroid/build/*; do
		if [ -e "$item" ] && [ "$(basename "$item")" != "extlib" ]; then
			acore_log_info "Removing: $(basename "$item")"
			rmrf_or_try_with_sudo "$item"
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
	rmrf_or_try_with_sudo "test/drift/app_database/generated/*"
fi

# Remove pub cache
acore_log_info "Removing pub cache..."
if [ -d ~/.pub-cache/hosted/pub.dev ]; then
	rmrf_or_try_with_sudo ~/.pub-cache/hosted/pub.dev/*
fi

# Remove .dart_tool
acore_log_info "Removing .dart_tool..."
if [ -d .dart_tool ]; then
	rmrf_or_try_with_sudo .dart_tool
fi

# Repair and get pub packages
acore_log_info "Repairing and fetching pub packages..."
fvm flutter pub cache repair || acore_log_warning "pub cache repair failed, continuing..."
fvm flutter pub get

# Run code generation
acore_log_info "Running code generation (rps gen)..."
bash "$PROJECT_ROOT/scripts/generate_gen_files.sh"

acore_log_success "Clean and generation completed."
