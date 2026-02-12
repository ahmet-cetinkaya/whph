#!/bin/bash

# Comprehensive linting script for WHPH project
# Runs Flutter analyze, dart_unused_files, markdownlint, shellcheck, and ktlint
# Usage: ./scripts/lint.sh

set -e

# Source universal logger from acore-scripts submodule
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOGGER_FILE="$PROJECT_ROOT/packages/acore-scripts/src/logger.sh"

# shellcheck source=../packages/acore-scripts/src/logger.sh
source "$LOGGER_FILE"

# Get project root and src directory
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"

acore_log_header "WHPH PROJECT LINTER"

# Change to src directory if it exists
if [[ -d "$SRC_DIR" ]]; then
    cd "$SRC_DIR"
    acore_log_info "Working in: $(pwd)"
else
    acore_log_error "src directory not found"
    exit 1
fi

# Track overall success
OVERALL_SUCCESS=true

# Function to run a linter and track success
run_linter() {
    local linter_name="$1"
    local linter_command="$2"
    local working_dir="$3"

    acore_log_section "🔍 Running $linter_name..."

    if [[ -n "$working_dir" ]]; then
        cd "$working_dir"
    fi

    if eval "$linter_command"; then
        acore_log_success "✅ $linter_name passed"
        if [[ -n "$working_dir" ]]; then
            cd "$SRC_DIR"
        fi
        return 0
    else
        acore_log_error "❌ $linter_name failed"
        if [[ -n "$working_dir" ]]; then
            cd "$SRC_DIR"
        fi
        OVERALL_SUCCESS=false
        return 1
    fi
}

# 1. Flutter analyze
# Note: Use --no-fatal-infos to avoid info messages about super parameters
# Use --no-fatal-warnings to ignore dead_code warnings (non-critical)
# We only fail if exit code is non-zero (actual errors, not warnings)
acore_log_section "🔍 Running Flutter Analyze..."
cd "$SRC_DIR"
if eval "fvm flutter analyze --no-fatal-infos --no-fatal-warnings"; then
    acore_log_success "✅ Flutter Analyze passed"
else
    acore_log_error "❌ Flutter Analyze failed with exit code $?"
    OVERALL_SUCCESS=false
fi

# 2. dart_unused_files scan
if command -v dart_unused_files &>/dev/null; then
    run_linter "Dart Unused Files" "dart_unused_files scan" "" || true
else
    acore_log_warning "⚠️ dart_unused_files not found, skipping unused files analysis"
    acore_log_info "Install with: dart pub global activate dart_unused_files"
fi

# 3. markdownlint-cli2 (run from project root to catch all markdown files)
if command -v markdownlint-cli2 &>/dev/null; then
    run_linter "Markdown Lint" "markdownlint-cli2 --fix \"**/*.md\"" "$PROJECT_ROOT" || true
else
    acore_log_warning "⚠️ markdownlint-cli2 not found, skipping markdown linting"
    acore_log_info "Install with: npm install -g markdownlint-cli2"
fi

# 4. Shell script linting (run from project root)
if command -v shellcheck &>/dev/null; then
    acore_log_section "🐚 Running Shellcheck on shell scripts..."
    cd "$PROJECT_ROOT"

    # Find and check shell scripts in one command
    # Exclude SC1091 (source file not found) as it's expected for optional files like .fdroid-venv
    if find . -name "*.sh" \
        -not -path "*/.git/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/.dart_tool/*" \
        -not -path "*/build/*" \
        -not -path "*/coverage/*" \
        -exec shellcheck -x -e SC1091 {} + 2>/dev/null; then
        acore_log_success "✅ Shellcheck passed"
    else
        acore_log_error "❌ Shellcheck failed"
        OVERALL_SUCCESS=false
    fi

    cd "$SRC_DIR"
else
    acore_log_warning "⚠️ shellcheck not found, skipping shell script linting"
    acore_log_info "Install from https://github.com/koalaman/shellcheck?tab=readme-ov-file#installing"
fi

# 5. Kotlin ktlint (run from project root for Android Kotlin files)
# Note: ktfmt handles formatting via 'rps format' pre-commit hook
# ktlint checks code quality issues and respects .editorconfig settings
if command -v ktlint &>/dev/null; then
    acore_log_section "🔍 Running ktlint on Kotlin files..."
    cd "$PROJECT_ROOT"

    # Run ktlint to check code quality
    # .editorconfig disables property-naming rule for uppercase TAG constants
    if ktlint "src/android/app/src/main/kotlin/**/*.kt"; then
        acore_log_success "✅ ktlint passed"
    else
        acore_log_error "❌ ktlint failed"
        acore_log_info "Note: This project uses ktfmt for formatting. ktlint checks code quality only."
        OVERALL_SUCCESS=false
    fi

    cd "$SRC_DIR"
else
    acore_log_warning "⚠️ ktlint not found, skipping Kotlin linting"
    acore_log_info "Install with: brew install ktlint (macOS) or see https://pinterest.github.io/ktlint/install/"
fi

# Final result
echo
echo "=================================================================="
if $OVERALL_SUCCESS; then
    acore_log_success "✅ ALL LINTERS PASSED!"
    echo "=================================================================="
    exit 0
else
    acore_log_error "❌ SOME LINTERS FAILED!"
    echo "=================================================================="
    exit 1
fi
