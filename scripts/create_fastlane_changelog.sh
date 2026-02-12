#!/bin/bash

# Script to create Fastlane changelogs for app stores
# Usage: ./scripts/create_fastlane_changelog.sh [version_code] [changelog_text] [--auto]
#
# Creates: fastlane/metadata/android/en-GB/changelogs/[version_code].txt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

CHANGELOG_DIR="$PROJECT_ROOT/fastlane/metadata/android/en-GB/changelogs"
PUBSPEC_FILE="$PROJECT_ROOT/src/pubspec.yaml"

# Parse arguments
AUTO_ACCEPT=false
VERSION_CODE=""
CHANGELOG_TEXT=""

for arg in "$@"; do
    case $arg in
    --auto)
        AUTO_ACCEPT=true
        shift
        ;;
    *)
        if [ -z "$VERSION_CODE" ]; then
            VERSION_CODE="$arg"
        elif [ -z "$CHANGELOG_TEXT" ]; then
            CHANGELOG_TEXT="$arg"
        fi
        shift
        ;;
    esac
done

# Get current version details
if [ -f "$PUBSPEC_FILE" ]; then
    CURRENT_VERSION_CODE=$(grep "^version:" "$PUBSPEC_FILE" | cut -d'+' -f2)
else
    acore_log_error "pubspec.yaml not found at $PUBSPEC_FILE"
    exit 1
fi

VERSION_CODE=${VERSION_CODE:-$CURRENT_VERSION_CODE}

# Function to capitalize first letter
capitalize() {
    local text="$1"
    echo "$(echo "${text:0:1}" | tr '[:lower:]' '[:upper:]')${text:1}"
}

# Function to generate from commits if no text provided
generate_from_commits() {
    local LATEST_TAG
    LATEST_TAG=$(git tag --sort=-version:refname | head -1)
    local COMMIT_RANGE=""

    if [ -z "$LATEST_TAG" ]; then
        COMMIT_RANGE="HEAD"
    else
        COMMIT_RANGE="$LATEST_TAG..HEAD"
    fi

    # Get user-facing changes
    local content=""
    while IFS= read -r commit; do
        if [ -n "$commit" ]; then
            MESSAGE=$(echo "$commit" | cut -d' ' -f2-)
            # Skip noise
            if [[ ! "$MESSAGE" =~ ^(chore:\ update\ app\ version|Merge\ ) ]]; then
                if [[ "$MESSAGE" =~ ^(feat|fix|perf|refactor)(\(.+\))?:\ (.+)$ ]]; then
                    local DESC
                    DESC=$(echo "$MESSAGE" | cut -d':' -f2- | sed 's/^ *//')
                    content="$content\n• $(capitalize "$DESC")"
                fi
            fi
        fi
    done < <(git log --oneline --no-merges "$COMMIT_RANGE")

    echo -e "$content"
}

if [ -z "$CHANGELOG_TEXT" ]; then
    acore_log_info "No changelog text provided. Generating from commits..."
    CHANGELOG_TEXT=$(generate_from_commits)

    if [ -z "$CHANGELOG_TEXT" ]; then
        CHANGELOG_TEXT="• Various behind-the-scenes improvements and optimizations"
    fi

    acore_log_section "Generated Fastlane Changelog"
    echo -e "$CHANGELOG_TEXT"

    if [ "$AUTO_ACCEPT" = false ]; then
        read -r -p "Do you want to use this changelog? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            acore_log_error "Cancelled."
            exit 1
        fi
    fi
else
    # Format manual text
    CHANGELOG_TEXT=$(echo -e "$CHANGELOG_TEXT" | sed 's/^[•-] //g' | while IFS= read -r line; do
        [ -n "$line" ] && echo "• $(capitalize "$line")"
    done)
fi

# Ensure directory exists
mkdir -p "$CHANGELOG_DIR"
CHANGELOG_FILE="$CHANGELOG_DIR/$VERSION_CODE.txt"

# Write file
echo -e "$CHANGELOG_TEXT" >"$CHANGELOG_FILE"

# Check size (500 bytes limit)
SIZE=$(wc -c <"$CHANGELOG_FILE")
if [ "$SIZE" -gt 500 ]; then
    acore_log_warning "Changelog exceeds 500 bytes ($SIZE bytes). Truncating..."
    HEAD_CONTENT=$(head -c 450 "$CHANGELOG_FILE")
    echo -e "$HEAD_CONTENT\n• ..." >"$CHANGELOG_FILE"
fi

acore_log_success "Created Fastlane changelog: $CHANGELOG_FILE"
acore_log_info "Size: $(wc -c <"$CHANGELOG_FILE") bytes"
