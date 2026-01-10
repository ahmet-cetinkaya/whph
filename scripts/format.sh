#!/bin/bash

# General formatting script for all project files
# Usage: ./scripts/format.sh

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# Get project root and src directory
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"

print_header "WHPH PROJECT FORMATTER"

# Change to src directory if it exists
if [[ -d "$SRC_DIR" ]]; then
    cd "$SRC_DIR"
    print_info "Working in: $(pwd)"
else
    print_error "src directory not found"
    exit 1
fi

# Pre-build exclude patterns for efficiency
EXCLUDES=(
    -not -path "*/.git/*"
    -not -path "*/.vscode/*"
    -not -path "*/.claude/*"
    -not -path "*/.idea/*"
    -not -path "*/node_modules/*"
    -not -path "*/.dart_tool/*"
    -not -path "*/build/*"
    -not -path "*/coverage/*"
)

# Create temp files for storing file lists
DART_FILES_LIST=$(mktemp)
JSON_FILES_LIST=$(mktemp)
YAML_FILES_LIST=$(mktemp)
MD_FILES_LIST=$(mktemp)
SHELL_FILES_LIST=$(mktemp)
KOTLIN_FILES_LIST=$(mktemp)

# Cleanup function
cleanup() {
    rm -f "$DART_FILES_LIST" "$JSON_FILES_LIST" "$YAML_FILES_LIST" "$MD_FILES_LIST" "$SHELL_FILES_LIST" "$KOTLIN_FILES_LIST"
}
trap cleanup EXIT

# Single pass to collect all files - much faster than multiple find calls
print_section "🔍 Scanning for files to format..."
find . \( \
    \( -name "*.dart" -not -name "*.g.dart" -not -name "*.mocks.dart" -not -name "*.log" \) \
    -o \( -name "*.json" \) \
    -o \( -name "*.yaml" -o -name "*.yml" \) \
    -o \( -name "*.md" \) \
    -o \( -name "*.kt" -o -name "*.kts" \) \
    \) "${EXCLUDES[@]}" | while IFS= read -r file; do
    case "$file" in
    *.dart) echo "$file" >>"$DART_FILES_LIST" ;;
    *.json) echo "$file" >>"$JSON_FILES_LIST" ;;
    *.yaml | *.yml) echo "$file" >>"$YAML_FILES_LIST" ;;
    *.md) echo "$file" >>"$MD_FILES_LIST" ;;
    *.kt | *.kts) echo "$file" >>"$KOTLIN_FILES_LIST" ;;
    esac
done

# Format Dart files (excluding generated files)
print_section "🔷 Formatting Dart Files"
DART_COUNT=$(wc -l <"$DART_FILES_LIST" 2>/dev/null || echo "0")
if [[ $DART_COUNT -gt 0 ]]; then
    print_info "Found $DART_COUNT Dart files to format (excluding generated files)"

    if command -v fvm &>/dev/null && [[ -f ".fvmrc" ]]; then
        print_info "🔧 Using FVM for Flutter formatting..."
        xargs -a "$DART_FILES_LIST" fvm dart format -l 120 || {
            print_warning "⚠️ FVM dart format failed, trying standard dart format..."
            xargs -a "$DART_FILES_LIST" dart format -l 120 || true
        }
    else
        print_info "🔧 Using standard Dart formatting..."
        xargs -a "$DART_FILES_LIST" dart format -l 120 || true
    fi
else
    print_info "No Dart files found to format"
fi

# Format JSON files
print_section "📋 Formatting JSON Files"
if command -v prettier &>/dev/null; then
    JSON_COUNT=$(wc -l <"$JSON_FILES_LIST" 2>/dev/null || echo "0")
    if [[ $JSON_COUNT -gt 0 ]]; then
        print_info "Found $JSON_COUNT JSON files to format"
        # Use prettier config from project root
        cd "$PROJECT_ROOT"
        sed "s|^\.|$SRC_DIR|" "$JSON_FILES_LIST" | xargs prettier --write --log-level error || true
        cd "$SRC_DIR"
    else
        print_info "No JSON files found to format"
    fi
else
    print_warning "⚠️ Prettier not found, skipping JSON formatting"
fi

# Format YAML files
print_section "📄 Formatting YAML Files"
if command -v prettier &>/dev/null; then
    YAML_COUNT=$(wc -l <"$YAML_FILES_LIST" 2>/dev/null || echo "0")
    if [[ $YAML_COUNT -gt 0 ]]; then
        print_info "Found $YAML_COUNT YAML files to format"
        # Use prettier config from project root
        cd "$PROJECT_ROOT"
        sed "s|^\.|$SRC_DIR|" "$YAML_FILES_LIST" | xargs prettier --write --log-level error || true
        cd "$SRC_DIR"
    else
        print_info "No YAML files found to format"
    fi
else
    print_warning "⚠️ Prettier not found, skipping YAML formatting"
fi

# Format Markdown files
print_section "📝 Formatting Markdown Files"
if command -v prettier &>/dev/null; then
    MD_COUNT=$(wc -l <"$MD_FILES_LIST" 2>/dev/null || echo "0")
    if [[ $MD_COUNT -gt 0 ]]; then
        print_info "Found $MD_COUNT Markdown files to format"
        # Convert relative paths to absolute paths for prettier
        cd "$PROJECT_ROOT"
        sed "s|^\.|$SRC_DIR|" "$MD_FILES_LIST" | xargs prettier --write --log-level error || true
        cd "$SRC_DIR"
    else
        print_info "No Markdown files found to format"
    fi
else
    print_warning "⚠️ Prettier not found, skipping Markdown formatting"
fi

# 🐚 Shell Script Formatting (run from project root)
print_section "🐚 Formatting shell scripts with shfmt..."
if command -v shfmt >/dev/null 2>&1; then
    cd "$PROJECT_ROOT"
    # Find and format shell scripts in one pass
    SHELL_FILES=$(find . -name "*.sh" "${EXCLUDES[@]}" 2>/dev/null | wc -l)
    if [[ $SHELL_FILES -gt 0 ]]; then
        print_info "Found $SHELL_FILES shell scripts to format"
        find . -name "*.sh" "${EXCLUDES[@]}" -print0 | xargs -0 shfmt -w -i 4 2>/dev/null || true
        print_success "✅ Shell scripts formatted"
    else
        print_warning "⚠️ No shell scripts found to format"
    fi
    cd "$SRC_DIR"
else
    print_error "❌ shfmt not found - skipping shell script formatting"
    print_warning "Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest"
fi

# 🎯 Kotlin Formatting with ktfmt
print_section "🎯 Formatting Kotlin files with ktfmt..."
KOTLIN_COUNT=$(wc -l <"$KOTLIN_FILES_LIST" 2>/dev/null || echo "0")
if [[ $KOTLIN_COUNT -gt 0 ]]; then
    print_info "Found $KOTLIN_COUNT Kotlin files to format"

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
        print_info "🔧 Using ktfmt for Kotlin formatting..."
        # Convert relative paths to absolute
        sed "s|^\.|$SRC_DIR|" "$KOTLIN_FILES_LIST" | xargs $KTFMT_CMD --google-style || {
            print_warning "⚠️ ktfmt formatting encountered some issues (continuing...)"
        }
        print_success "✅ Kotlin files formatted"
    else
        print_warning "⚠️ ktfmt not found - skipping Kotlin formatting"
        print_warning "Install options:"
        print_warning "  - macOS: brew install ktfmt"
        print_warning "  - Manual: Download ktfmt jar and place in tools/ directory"
        print_warning "  - Visit: https://github.com/facebook/ktfmt"
    fi
else
    print_info "No Kotlin files found to format"
fi

print_success "✅ All files have been formatted successfully!"
