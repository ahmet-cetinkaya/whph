#!/bin/bash

# Script to create changelogs following "Keep a Changelog" standards
# Usage: ./scripts/create_changelog.sh [version_code] [changelog_text] [--auto]
# If changelog_text is not provided, it will be auto-generated from commit messages since the last version tag
# Use --auto flag to automatically accept generated changelog without confirmation
# 
# Creates two changelogs:
# 1. Project root CHANGELOG.md (Keep a Changelog format)
# 2. Fastlane changelog for app stores

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CHANGELOG_DIR="$PROJECT_ROOT/android/fastlane/metadata/android/en-US/changelogs"
MAIN_CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"

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

# Get current version code from pubspec.yaml
CURRENT_VERSION_CODE=$(grep "version:" "$PROJECT_ROOT/pubspec.yaml" | cut -d'+' -f2)
CURRENT_VERSION=$(grep "version:" "$PROJECT_ROOT/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1)

VERSION_CODE=${VERSION_CODE:-$CURRENT_VERSION_CODE}

# Function to generate changelog from git commits
generate_changelog_from_commits() {
    cd "$PROJECT_ROOT"
    
    # Get the latest version tag
    LATEST_TAG=$(git tag --sort=-version:refname | head -1)
    
    if [ -z "$LATEST_TAG" ]; then
        echo "Warning: No version tags found. Using all commits from the beginning." >&2
        COMMIT_RANGE="HEAD"
    else
        COMMIT_RANGE="$LATEST_TAG..HEAD"
        echo "Generating changelog from commits since tag: $LATEST_TAG" >&2
    fi
    
    # Get commit messages and categorize them
    ADDED=""
    CHANGED=""
    DEPRECATED=""
    REMOVED=""
    FIXED=""
    SECURITY=""
    
    while IFS= read -r commit; do
        if [ -n "$commit" ]; then
            # Extract commit message (everything after the hash and space)
            MESSAGE=$(echo "$commit" | cut -d' ' -f2-)
            
            # Skip version bump commits and merge commits
            if [[ ! "$MESSAGE" =~ ^(chore:\ update\ app\ version|Merge\ ) ]]; then
                # Categorize commit message - only user-facing changes
                if [[ "$MESSAGE" =~ ^(feat|fix|docs|style|refactor|perf|test|chore|ci|build)(\(.+\))?:\ (.+)$ ]]; then
                    # Conventional commit format
                    TYPE=$(echo "$MESSAGE" | cut -d':' -f1 | sed 's/(.*//')
                    DESCRIPTION=$(echo "$MESSAGE" | cut -d':' -f2- | sed 's/^ *//')
                    
                    # Only include user-facing commit types
                    case "$TYPE" in
                        "feat")
                            # New features for users
                            if [ -z "$ADDED" ]; then
                                ADDED="- $DESCRIPTION"
                            else
                                ADDED="$ADDED\n- $DESCRIPTION"
                            fi
                            ;;
                        "fix")
                            # Bug fixes
                            if [ -z "$FIXED" ]; then
                                FIXED="- $DESCRIPTION"
                            else
                                FIXED="$FIXED\n- $DESCRIPTION"
                            fi
                            ;;
                        "perf")
                            # Performance improvements
                            if [ -z "$CHANGED" ]; then
                                CHANGED="- $DESCRIPTION"
                            else
                                CHANGED="$CHANGED\n- $DESCRIPTION"
                            fi
                            ;;
                        "refactor")
                            # Only include refactors that affect user experience
                            if [[ "$DESCRIPTION" =~ (UI|user|interface|experience|performance) ]]; then
                                if [ -z "$CHANGED" ]; then
                                    CHANGED="- $DESCRIPTION"
                                else
                                    CHANGED="$CHANGED\n- $DESCRIPTION"
                                fi
                            fi
                            ;;
                        # Skip these types as they don't affect end users:
                        # "docs" - documentation changes
                        # "style" - code style changes  
                        # "test" - test additions/changes
                        # "build" - build system changes
                        # "ci" - CI/CD changes
                        # "chore" - maintenance tasks
                    esac
                else
                    # Non-conventional commit - only include if it seems user-facing
                    if [[ "$MESSAGE" =~ ^(add|new|create).*(feature|function|capability) ]] || \
                       [[ "$MESSAGE" =~ ^(improve|enhance|update).*(UI|user|interface|performance) ]] || \
                       [[ "$MESSAGE" =~ ^(fix|resolve|correct).*(bug|issue|problem|error) ]]; then
                        
                        if [[ "$MESSAGE" =~ ^(add|new|create) ]]; then
                            if [ -z "$ADDED" ]; then
                                ADDED="- $MESSAGE"
                            else
                                ADDED="$ADDED\n- $MESSAGE"
                            fi
                        elif [[ "$MESSAGE" =~ ^(fix|resolve|correct) ]]; then
                            if [ -z "$FIXED" ]; then
                                FIXED="- $MESSAGE"
                            else
                                FIXED="$FIXED\n- $MESSAGE"
                            fi
                        else
                            if [ -z "$CHANGED" ]; then
                                CHANGED="- $MESSAGE"
                            else
                                CHANGED="$CHANGED\n- $MESSAGE"
                            fi
                        fi
                    fi
                    # Skip all other non-conventional commits (likely internal/dev changes)
                fi
            fi
        fi
    done < <(git log --oneline --no-merges $COMMIT_RANGE)
    
    # Build changelog sections
    CHANGELOG_SECTIONS=""
    
    if [ -n "$ADDED" ]; then
        CHANGELOG_SECTIONS="### Added\n$ADDED\n"
    fi
    
    if [ -n "$CHANGED" ]; then
        if [ -n "$CHANGELOG_SECTIONS" ]; then
            CHANGELOG_SECTIONS="$CHANGELOG_SECTIONS\n### Changed\n$CHANGED\n"
        else
            CHANGELOG_SECTIONS="### Changed\n$CHANGED\n"
        fi
    fi
    
    if [ -n "$DEPRECATED" ]; then
        if [ -n "$CHANGELOG_SECTIONS" ]; then
            CHANGELOG_SECTIONS="$CHANGELOG_SECTIONS\n### Deprecated\n$DEPRECATED\n"
        else
            CHANGELOG_SECTIONS="### Deprecated\n$DEPRECATED\n"
        fi
    fi
    
    if [ -n "$REMOVED" ]; then
        if [ -n "$CHANGELOG_SECTIONS" ]; then
            CHANGELOG_SECTIONS="$CHANGELOG_SECTIONS\n### Removed\n$REMOVED\n"
        else
            CHANGELOG_SECTIONS="### Removed\n$REMOVED\n"
        fi
    fi
    
    if [ -n "$FIXED" ]; then
        if [ -n "$CHANGELOG_SECTIONS" ]; then
            CHANGELOG_SECTIONS="$CHANGELOG_SECTIONS\n### Fixed\n$FIXED\n"
        else
            CHANGELOG_SECTIONS="### Fixed\n$FIXED\n"
        fi
    fi
    
    if [ -n "$SECURITY" ]; then
        if [ -n "$CHANGELOG_SECTIONS" ]; then
            CHANGELOG_SECTIONS="$CHANGELOG_SECTIONS\n### Security\n$SECURITY\n"
        else
            CHANGELOG_SECTIONS="### Security\n$SECURITY\n"
        fi
    fi
    
    echo -e "$CHANGELOG_SECTIONS"
}

# Function to convert Keep a Changelog format to simple bullet points for Fastlane
convert_to_fastlane_format() {
    local keep_a_changelog_content="$1"
    
    echo "$keep_a_changelog_content" | \
    grep "^- " | \
    sed 's/^- /• /' | \
    head -20  # Limit to first 20 items to stay under byte limit
}

# Function to create or update main CHANGELOG.md
update_main_changelog() {
    local version="$1"
    local changelog_content="$2"
    local date=$(date +%Y-%m-%d)
    
    local new_entry="## [$version] - $date\n\n$changelog_content"
    
    if [ ! -f "$MAIN_CHANGELOG" ]; then
        # Create new CHANGELOG.md
        cat > "$MAIN_CHANGELOG" << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

$new_entry

EOF
    else
        # Update existing CHANGELOG.md
        # Insert new entry after "## [Unreleased]" line
        if grep -q "## \[Unreleased\]" "$MAIN_CHANGELOG"; then
            # Create temporary file with new entry
            awk -v new_entry="$new_entry" '
                /^## \[Unreleased\]/ {
                    print $0
                    print ""
                    printf "%s", new_entry
                    print ""
                    next
                }
                { print }
            ' "$MAIN_CHANGELOG" > "$MAIN_CHANGELOG.tmp"
            mv "$MAIN_CHANGELOG.tmp" "$MAIN_CHANGELOG"
        else
            # If no Unreleased section, add after the header
            awk -v new_entry="$new_entry" '
                NR <= 5 && /^# Changelog/ {
                    # Print header lines until we find the main header
                    while ((getline line) > 0 && line !~ /^## /) {
                        print line
                    }
                    print ""
                    print "## [Unreleased]"
                    print ""
                    print new_entry
                    print ""
                    if (line ~ /^## /) print line  # Print the line we read ahead
                    next
                }
                { print }
            ' "$MAIN_CHANGELOG" > "$MAIN_CHANGELOG.tmp"
            mv "$MAIN_CHANGELOG.tmp" "$MAIN_CHANGELOG"
        fi
    fi
}

if [ -z "$CHANGELOG_TEXT" ]; then
    echo "No changelog text provided. Generating from commit messages..."
    CHANGELOG_CONTENT=$(generate_changelog_from_commits)
    
    if [ -z "$CHANGELOG_CONTENT" ]; then
        echo "No user-facing changes found since last version."
        echo "All commits appear to be internal changes (CI, build, tests, etc.)"
        CHANGELOG_CONTENT="### Changed\n- Internal improvements and maintenance"
    fi
    
    echo ""
    echo "Generated changelog (Keep a Changelog format):"
    echo -e "$CHANGELOG_CONTENT"
    echo ""
    
    # Convert to Fastlane format for preview
    FASTLANE_CHANGELOG=$(convert_to_fastlane_format "$CHANGELOG_CONTENT")
    echo "Fastlane format preview:"
    echo -e "$FASTLANE_CHANGELOG"
    echo ""
    
    if [ "$AUTO_ACCEPT" = true ]; then
        echo "Auto-accepting generated changelog (--auto flag provided)"
        CHANGELOG_TEXT="$FASTLANE_CHANGELOG"
    else
        read -p "Do you want to use this generated changelog? (y/N): " confirm
        
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Usage: $0 [version_code] \"changelog text\" [--auto]"
            echo "Current version code: $CURRENT_VERSION_CODE"
            echo "Current version: $CURRENT_VERSION"
            echo ""
            echo "Example:"
            echo "  $0 31 \"• New feature added\n• Bug fixes\n• Performance improvements\""
            echo "  $0 --auto  # Auto-generate and accept changelog"
            exit 1
        fi
        
        CHANGELOG_TEXT="$FASTLANE_CHANGELOG"
    fi
    
    # Update main CHANGELOG.md
    echo "Updating main CHANGELOG.md..."
    update_main_changelog "$CURRENT_VERSION" "$CHANGELOG_CONTENT"
    echo "✅ Updated $MAIN_CHANGELOG"
    
else
    # Manual changelog provided - create a simple Keep a Changelog entry
    MANUAL_CONTENT="### Changed\n$(echo -e "$CHANGELOG_TEXT" | sed 's/^• /- /g')"
    update_main_changelog "$CURRENT_VERSION" "$MANUAL_CONTENT"
    echo "✅ Updated $MAIN_CHANGELOG with manual changelog"
fi

CHANGELOG_FILE="$CHANGELOG_DIR/$VERSION_CODE.txt"

# Create changelog directory if it doesn't exist
mkdir -p "$CHANGELOG_DIR"

# Create changelog file
echo -e "$CHANGELOG_TEXT" > "$CHANGELOG_FILE"

# Check file size (F-Droid limit: 500 bytes)
FILE_SIZE=$(wc -c < "$CHANGELOG_FILE")
if [ $FILE_SIZE -gt 500 ]; then
    echo "Warning: Changelog is $FILE_SIZE bytes, which exceeds F-Droid's 500 byte limit"
    echo "Please shorten the changelog text."
    exit 1
fi

echo "Created changelog for version code $VERSION_CODE:"
echo "📱 Fastlane: $CHANGELOG_FILE"
echo "📝 Main: $MAIN_CHANGELOG"
echo "Size: $FILE_SIZE bytes"
echo ""
echo "Fastlane content:"
cat "$CHANGELOG_FILE"
