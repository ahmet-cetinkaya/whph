#!/bin/bash

# General formatting script for all project files
# Usage: ./scripts/format.sh

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

# Get project root and src directory
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"

acore_log_header "WHPH PROJECT FORMATTER"

# Change to src directory if it exists
if [[ -d "$SRC_DIR" ]]; then
	cd "$SRC_DIR"
	acore_log_info "Working in: $(pwd)"
else
	acore_log_error "src directory not found"
	exit 1
fi

# Change back to src directory for formatting
cd "$SRC_DIR"

# Create temp files for storing file lists
DART_FILES_LIST=$(mktemp)
JSON_FILES_LIST=$(mktemp)
YAML_FILES_LIST=$(mktemp)
MD_FILES_LIST=$(mktemp)
SHELL_FILES_LIST=$(mktemp)
KOTLIN_FILES_LIST=$(mktemp)
CPP_FILES_LIST=$(mktemp)

# Cleanup function
cleanup() {
	rm -f "$DART_FILES_LIST" "$JSON_FILES_LIST" "$YAML_FILES_LIST" "$MD_FILES_LIST" "$SHELL_FILES_LIST" "$KOTLIN_FILES_LIST" "$CPP_FILES_LIST"
}
trap cleanup EXIT

# Collect all files - using fd with gitignore support
acore_log_section "🔍 Scanning for files to format..."
fd -e dart -t f . . 2>/dev/null | grep -v '\.g\.dart$' | grep -v '\.mocks\.dart$' | grep -v '\.log$' >>"$DART_FILES_LIST"
fd -e json -t f . . 2>/dev/null >>"$JSON_FILES_LIST"
fd -e yaml -e yml -t f . . 2>/dev/null >>"$YAML_FILES_LIST"
fd -e md -t f . . 2>/dev/null >>"$MD_FILES_LIST"
fd -e kt -e kts -t f . . 2>/dev/null >>"$KOTLIN_FILES_LIST"
fd -e cpp -e h -t f . . 2>/dev/null >>"$CPP_FILES_LIST"

# Format Dart files (excluding generated files)
acore_log_section "🔷 Formatting Dart Files"
DART_COUNT=$(wc -l <"$DART_FILES_LIST" 2>/dev/null || echo "0")
if [[ $DART_COUNT -gt 0 ]]; then
	acore_log_info "Found $DART_COUNT Dart files to format (excluding generated files)"

	if command -v fvm &>/dev/null && [[ -f ".fvmrc" ]]; then
		acore_log_info "🔧 Using FVM for Flutter formatting..."
		xargs -a "$DART_FILES_LIST" fvm dart format -l 120 || {
			acore_log_warning "⚠️ FVM dart format failed, trying standard dart format..."
			xargs -a "$DART_FILES_LIST" dart format -l 120 || true
		}
	else
		acore_log_info "🔧 Using standard Dart formatting..."
		xargs -a "$DART_FILES_LIST" dart format -l 120 || true
	fi
else
	acore_log_info "No Dart files found to format"
fi

# Format JSON files
acore_log_section "📋 Formatting JSON Files"
if command -v prettier &>/dev/null; then
	JSON_COUNT=$(wc -l <"$JSON_FILES_LIST" 2>/dev/null || echo "0")
	if [[ $JSON_COUNT -gt 0 ]]; then
		acore_log_info "Found $JSON_COUNT JSON files to format"
		# Use prettier config from project root
		cd "$PROJECT_ROOT"
		sed "s|^\.|$SRC_DIR|" "$JSON_FILES_LIST" | xargs prettier --write --log-level error || true
		cd "$SRC_DIR"
	else
		acore_log_info "No JSON files found to format"
	fi
else
	acore_log_warning "⚠️ Prettier not found, skipping JSON formatting"
fi

# Format YAML files
acore_log_section "📄 Formatting YAML Files"
if command -v prettier &>/dev/null; then
	YAML_COUNT=$(wc -l <"$YAML_FILES_LIST" 2>/dev/null || echo "0")
	if [[ $YAML_COUNT -gt 0 ]]; then
		acore_log_info "Found $YAML_COUNT YAML files to format"
		# Use prettier config from project root
		cd "$PROJECT_ROOT"
		sed "s|^\.|$SRC_DIR|" "$YAML_FILES_LIST" | xargs prettier --write --log-level error || true
		cd "$SRC_DIR"
	else
		acore_log_info "No YAML files found to format"
	fi
else
	acore_log_warning "⚠️ Prettier not found, skipping YAML formatting"
fi

# Format Markdown files
acore_log_section "📝 Formatting Markdown Files"
if command -v prettier &>/dev/null; then
	MD_COUNT=$(wc -l <"$MD_FILES_LIST" 2>/dev/null || echo "0")
	if [[ $MD_COUNT -gt 0 ]]; then
		acore_log_info "Found $MD_COUNT Markdown files to format"
		# Convert relative paths to absolute paths for prettier
		cd "$PROJECT_ROOT"
		sed "s|^\.|$SRC_DIR|" "$MD_FILES_LIST" | xargs prettier --write --log-level error || true
		cd "$SRC_DIR"
	else
		acore_log_info "No Markdown files found to format"
	fi
else
	acore_log_warning "⚠️ Prettier not found, skipping Markdown formatting"
fi

# 🐚 Shell Script Formatting (run from project root)
acore_log_section "🐚 Formatting shell scripts with shfmt..."
if command -v shfmt >/dev/null 2>&1; then
	cd "$PROJECT_ROOT"
	SHELL_FILES=$(fd -e sh -t f . . 2>/dev/null | wc -l)
	if [[ $SHELL_FILES -gt 0 ]]; then
		acore_log_info "Found $SHELL_FILES shell scripts to format"
		fd -e sh -t f . . 2>/dev/null | xargs -0 shfmt -w -i 4 2>/dev/null || true
		acore_log_success "✅ Shell scripts formatted"
	else
		acore_log_warning "⚠️ No shell scripts found to format"
	fi
	cd "$SRC_DIR"
else
	acore_log_error "❌ shfmt not found - skipping shell script formatting"
	acore_log_warning "Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest"
fi

# 🎯 Kotlin Formatting with ktfmt
acore_log_section "🎯 Formatting Kotlin files with ktfmt..."
KOTLIN_COUNT=$(wc -l <"$KOTLIN_FILES_LIST" 2>/dev/null || echo "0")
if [[ $KOTLIN_COUNT -gt 0 ]]; then
	acore_log_info "Found $KOTLIN_COUNT Kotlin files to format"

	# Check for ktfmt in various ways
	KTFMT_CMD=""
	if command -v ktfmt >/dev/null 2>&1; then
		KTFMT_CMD="ktfmt"
	elif [[ -f "$PROJECT_ROOT/.ktfmt" ]] || command -v java >/dev/null 2>&1; then
		# Try to use ktfmt via a wrapper script or check if jar exists
		if [[ -f "$PROJECT_ROOT/scripts/ktfmt" ]]; then
			KTFMT_CMD="$PROJECT_ROOT/scripts/ktfmt"
		elif [[ -f "$PROJECT_ROOT/tools/ktfmt.jar" ]]; then
			KTFMT_CMD="java -jar $PROJECT_ROOT/tools/ktfmt.jar"
		fi
	fi

	if [[ -n "$KTFMT_CMD" ]]; then
		acore_log_info "🔧 Using ktfmt for Kotlin formatting..."
		# Convert relative paths to absolute
		# shellcheck disable=SC2086  # Word splitting intentional for xargs command with args
		sed "s|^\.|$SRC_DIR|" "$KOTLIN_FILES_LIST" | xargs $KTFMT_CMD --google-style || {
			acore_log_warning "⚠️ ktfmt formatting encountered some issues (continuing...)"
		}
		acore_log_success "✅ Kotlin files formatted"
	else
		acore_log_warning "⚠️ ktfmt not found - skipping Kotlin formatting"
		acore_log_warning "Install options:"
		acore_log_warning "  - macOS: brew install ktfmt"
		acore_log_warning "  - Manual: Download ktfmt jar and place in tools/ directory"
		acore_log_warning "  - Visit: https://github.com/facebook/ktfmt"
	fi
else
	acore_log_info "No Kotlin files found to format"
fi

# 🛠️ C++ Formatting with clang-format
acore_log_section "🛠️ Formatting C++ files with clang-format..."
CPP_COUNT=$(wc -l <"$CPP_FILES_LIST" 2>/dev/null || echo "0")
if [[ $CPP_COUNT -gt 0 ]]; then
	acore_log_info "Found $CPP_COUNT C++ files to format"

	if command -v clang-format >/dev/null 2>&1; then
		acore_log_info "🔧 Using clang-format for C++ formatting..."
		# Convert relative paths to absolute and run clang-format
		sed "s|^\.|$SRC_DIR|" "$CPP_FILES_LIST" | xargs clang-format -i || {
			acore_log_warning "⚠️ clang-format encountered some issues (continuing...)"
		}
		acore_log_success "✅ C++ files formatted"
	else
		acore_log_warning "⚠️ clang-format not found - skipping C++ formatting"
		acore_log_warning "Install with: sudo apt install clang-format"
	fi
else
	acore_log_info "No C++ files found to format"
fi

acore_log_success "✅ All files have been formatted successfully!"
