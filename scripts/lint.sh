#!/bin/bash

# Comprehensive linting script for WHPH project
# Runs Flutter analyze, dart_unused_files, markdownlint, and shellcheck
# Usage: ./scripts/lint.sh

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_FILE="$SCRIPT_DIR/_common.sh"

# Check if _common.sh exists, otherwise define fallback functions
if [[ -f "$COMMON_FILE" ]]; then
    # shellcheck source=./_common.sh
    source "$COMMON_FILE"
else
    # Fallback color definitions and functions if _common.sh is not available
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color

    print_info() {
        echo -e "${BLUE}[INFO]${NC} $1"
    }

    print_success() {
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    }

    print_warning() {
        echo -e "${YELLOW}[WARNING]${NC} $1"
    }

    print_error() {
        echo -e "${RED}[ERROR]${NC} $1"
    }

    print_header() {
        echo
        echo "=================================================================="
        echo "$1"
        echo "=================================================================="
        echo
    }

    print_section() {
        echo
        echo "--- $1 ---"
        echo
    }
fi

# Get project root and src directory
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"

print_header "WHPH PROJECT LINTER"

# Change to src directory if it exists
if [[ -d "$SRC_DIR" ]]; then
    cd "$SRC_DIR"
    print_info "Working in: $(pwd)"
else
    print_error "src directory not found"
    exit 1
fi

# Track overall success
OVERALL_SUCCESS=true

# Function to run a linter and track success
run_linter() {
    local linter_name="$1"
    local linter_command="$2"
    local working_dir="$3"

    print_section "🔍 Running $linter_name..."

    if [[ -n "$working_dir" ]]; then
        cd "$working_dir"
    fi

    if eval "$linter_command"; then
        print_success "✅ $linter_name passed"
        if [[ -n "$working_dir" ]]; then
            cd "$SRC_DIR"
        fi
        return 0
    else
        print_error "❌ $linter_name failed"
        if [[ -n "$working_dir" ]]; then
            cd "$SRC_DIR"
        fi
        OVERALL_SUCCESS=false
        return 1
    fi
}

# 1. Flutter analyze
run_linter "Flutter Analyze" "fvm flutter analyze" "" || true

# 2. dart_unused_files scan
if command -v dart_unused_files &>/dev/null; then
    run_linter "Dart Unused Files" "dart_unused_files scan" "" || true
else
    print_warning "⚠️ dart_unused_files not found, skipping unused files analysis"
    print_info "Install with: dart pub global activate dart_unused_files"
fi

# 3. markdownlint-cli2 (run from project root to catch all markdown files)
if command -v markdownlint-cli2 &>/dev/null; then
    run_linter "Markdown Lint" "markdownlint-cli2 --fix \"**/*.md\"" "$PROJECT_ROOT" || true
else
    print_warning "⚠️ markdownlint-cli2 not found, skipping markdown linting"
    print_info "Install with: npm install -g markdownlint-cli2"
fi

# 4. Shell script linting (run from project root)
if command -v shellcheck &>/dev/null; then
    print_section "🐚 Running Shellcheck on shell scripts..."
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
        print_success "✅ Shellcheck passed"
    else
        print_error "❌ Shellcheck failed"
        OVERALL_SUCCESS=false
    fi

    cd "$SRC_DIR"
else
    print_warning "⚠️ shellcheck not found, skipping shell script linting"
    print_info "Install from https://github.com/koalaman/shellcheck?tab=readme-ov-file#installing"
fi

# Final result
echo
echo "=================================================================="
if $OVERALL_SUCCESS; then
    print_success "✅ ALL LINTERS PASSED!"
    echo "=================================================================="
    exit 0
else
    print_error "❌ SOME LINTERS FAILED!"
    echo "=================================================================="
    exit 1
fi
