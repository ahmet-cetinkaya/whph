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

# Function to build exclude patterns from gitignore files
build_exclude_patterns() {
    local exclude_patterns=()

    # Read project root .gitignore
    if [[ -f "$PROJECT_ROOT/.gitignore" ]]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// /}" ]] && continue

            # Convert gitignore pattern to find exclude pattern
            if [[ "$line" == */ ]]; then
                # Directory pattern - use -path
                exclude_patterns+=("-not -path" "*/${line}*")
            elif [[ "$line" == *"*"* ]]; then
                # Wildcard pattern - use -name directly for simple patterns
                if [[ "$line" == *"/"* ]]; then
                    # Contains directory separator - use -path with regex
                    pattern="${line//\*/.*}"
                    exclude_patterns+=("-not -path" "*${pattern}*")
                else
                    # Simple filename with wildcard - use -name directly
                    exclude_patterns+=("-not -name" "$line")
                fi
            elif [[ "$line" == *"/"* ]]; then
                # Contains directory separator - use -path
                exclude_patterns+=("-not -path" "*/$line")
            else
                # Simple file/directory name - use -name for files, -path for directories
                exclude_patterns+=("-not -name" "$line")
            fi
        done <"$PROJECT_ROOT/.gitignore"
    fi

    # Read src/.gitignore if it exists
    if [[ -f "$SRC_DIR/.gitignore" ]]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// /}" ]] && continue

            if [[ "$line" == */ ]]; then
                exclude_patterns+=("-not -path" "*/src/${line}*")
            elif [[ "$line" == *"*"* ]]; then
                if [[ "$line" == *"/"* ]]; then
                    # Contains directory separator - use -path with regex
                    pattern="${line//\*/.*}"
                    exclude_patterns+=("-not -path" "*src/${pattern}*")
                else
                    # Simple filename with wildcard - use -name directly
                    exclude_patterns+=("-not -name" "$line")
                fi
            elif [[ "$line" == *"/"* ]]; then
                exclude_patterns+=("-not -path" "*/src/$line")
            else
                exclude_patterns+=("-not -name" "$line")
            fi
        done <"$SRC_DIR/.gitignore"
    fi

    # Always add common excludes for IDE and tool files - use -path for directories
    exclude_patterns+=(
        "-not -path" "*/.git/*"
        "-not -path" "*/.vscode/*"
        "-not -path" "*/.claude/*"
        "-not -path" "*/.idea/*"
        "-not -path" "*/node_modules/*"
        "-not -path" "*/.dart_tool/*"
        "-not -path" "*/build/*"
        "-not -path" "*/coverage/*"
    )

    # Return the array directly (caller should use: patterns=($(build_exclude_patterns)))
    printf '%s\n' "${exclude_patterns[@]}"
}

print_header "WHPH PROJECT FORMATTER"

# Change to src directory if it exists
if [[ -d "$SRC_DIR" ]]; then
    cd "$SRC_DIR"
    print_info "Working in: $(pwd)"
else
    print_error "src directory not found"
    exit 1
fi

# Get dynamic exclude patterns
readarray -t EXCLUDE_PATTERNS < <(build_exclude_patterns)

# Debug: Show exclude patterns (remove echo for production)
# print_info "Exclude patterns: ${#EXCLUDE_PATTERNS[@]} patterns loaded"

# Format Dart files (excluding generated files)
print_section "🔷 Formatting Dart Files"
DART_FILES=$(find . -name "*.dart" -not -name "*.g.dart" -not -name "*.mocks.dart" -not -name "*.log" -not -path "*/.dart_tool/*" -not -path "*/build/*" | wc -l)
print_info "Found $DART_FILES Dart files to format (excluding generated files)"

if command -v fvm &>/dev/null && [[ -f ".fvmrc" ]]; then
    print_info "🔧 Using FVM for Flutter formatting..."
    find . -name "*.dart" -not -name "*.g.dart" -not -name "*.mocks.dart" -not -name "*.log" -not -path "*/.dart_tool/*" -not -path "*/build/*" -print0 | xargs -0 fvm dart format -l 120
else
    print_info "🔧 Using standard Dart formatting..."
    find . -name "*.dart" -not -name "*.g.dart" -not -name "*.mocks.dart" -not -name "*.log" -not -path "*/.dart_tool/*" -not -path "*/build/*" -print0 | xargs -0 dart format -l 120
fi

# Format JSON files
print_section "📋 Formatting JSON Files"
if command -v prettier &>/dev/null; then
    JSON_FILES=$(find . -name "*.json" -not -path "*/.vscode/*" -not -path "*/.claude/*" -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.dart_tool/*" -not -path "*/build/*" | wc -l)
    if [[ $JSON_FILES -gt 0 ]]; then
        print_info "Found $JSON_FILES JSON files to format"
        find . -name "*.json" -not -path "*/.vscode/*" -not -path "*/.claude/*" -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.dart_tool/*" -not -path "*/build/*" -exec prettier --write --log-level error {} \;
    else
        print_info "No JSON files found to format"
    fi
else
    print_warning "⚠️ Prettier not found, skipping JSON formatting"
fi

# Format YAML files
print_section "📄 Formatting YAML Files"
if command -v prettier &>/dev/null; then
    YAML_FILES=$(find . \( -name "*.yaml" -o -name "*.yml" \) -not -path "*/.vscode/*" -not -path "*/.claude/*" -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.dart_tool/*" -not -path "*/build/*" | wc -l)
    if [[ $YAML_FILES -gt 0 ]]; then
        print_info "Found $YAML_FILES YAML files to format"
        find . \( -name "*.yaml" -o -name "*.yml" \) -not -path "*/.vscode/*" -not -path "*/.claude/*" -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.dart_tool/*" -not -path "*/build/*" -exec prettier --write --log-level error {} \;
    else
        print_info "No YAML files found to format"
    fi
else
    print_warning "⚠️ Prettier not found, skipping YAML formatting"
fi

# Format Markdown files
print_section "📝 Formatting Markdown Files"
if command -v prettier &>/dev/null; then
    MARKDOWN_FILES=$(find . -name "*.md" -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.dart_tool/*" -not -path "*/build/*" | wc -l)
    if [[ $MARKDOWN_FILES -gt 0 ]]; then
        print_info "Found $MARKDOWN_FILES Markdown files to format"
        find . -name "*.md" -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.dart_tool/*" -not -path "*/build/*" -exec prettier --write --prose-wrap=preserve --log-level error {} \;
    else
        print_info "No Markdown files found to format"
    fi
else
    print_warning "⚠️ Prettier not found, skipping Markdown formatting"
fi

# 🐚 Shell Script Formatting
print_section "🐚 Formatting shell scripts with shfmt..."
if command -v shfmt >/dev/null 2>&1; then
    # Temporarily go to project root to build correct exclude patterns
    cd "$PROJECT_ROOT"
    SHELL_FILES=$(find . -name "*.sh" -not -path "*/.git/*" -not -path "*/.vscode/*" -not -path "*/.claude/*" -not -path "*/node_modules/*" -not -path "*/.dart_tool/*" -not -path "*/build/*" | wc -l)
    if [ "$SHELL_FILES" -gt 0 ]; then
        print_info "Found $SHELL_FILES shell scripts to format"
        find . -name "*.sh" -not -path "*/.git/*" -not -path "*/.vscode/*" -not -path "*/.claude/*" -not -path "*/node_modules/*" -not -path "*/.dart_tool/*" -not -path "*/build/*" -print0 | xargs -0 shfmt -w -i 4 2>/dev/null || true
        print_success "✅ Shell scripts formatted"
    else
        print_warning "⚠️ No shell scripts found to format"
    fi
    # Return to src directory
    cd "$SRC_DIR"
else
    print_error "❌ shfmt not found - skipping shell script formatting"
    print_warning "Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest"
fi

print_success "✅ All files have been formatted successfully!"
