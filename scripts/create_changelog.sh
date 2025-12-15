#!/bin/bash

# Script to create changelogs following "Keep a Changelog" standards
# Usage: ./scripts/create_changelog.sh [version_code] [changelog_text] [--auto] [--all-versions]
# If changelog_text is not provided, it will be auto-generated from commit messages since the last version tag
# Use --auto flag to automatically accept generated changelog without confirmation
# Use --all-versions flag to generate changelog for all historical versions
#
# Creates two changelogs:
# 1. Project root CHANGELOG.md (Keep a Changelog format)
# 2. Fastlane changelog for app stores

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CHANGELOG_DIR="$PROJECT_ROOT/fastlane/metadata/android/en-GB/changelogs"
MAIN_CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"

# Parse arguments
AUTO_ACCEPT=false
ALL_VERSIONS=false
VERSION_CODE=""
CHANGELOG_TEXT=""

for arg in "$@"; do
    case $arg in
    --auto)
        AUTO_ACCEPT=true
        shift
        ;;
    --all-versions)
        ALL_VERSIONS=true
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

# Get current version code from src/pubspec.yaml
CURRENT_VERSION_CODE=$(grep "^version:" "$PROJECT_ROOT/src/pubspec.yaml" | cut -d'+' -f2)
CURRENT_VERSION=$(grep "^version:" "$PROJECT_ROOT/src/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1)

VERSION_CODE=${VERSION_CODE:-$CURRENT_VERSION_CODE}

# Function to capitalize first letter of a string
capitalize_first_letter() {
    local text="$1"
    echo "$(echo "${text:0:1}" | tr '[:lower:]' '[:upper:]')${text:1}"
}

# Function to generate changelog from git commits
generate_changelog_from_commits() {
    local start_tag="$1"
    local end_tag="$2"

    cd "$PROJECT_ROOT"

    # If generating for current version (no parameters), use latest tag to HEAD
    if [ -z "$start_tag" ] && [ -z "$end_tag" ]; then
        # Get the latest version tag
        LATEST_TAG=$(git tag --sort=-version:refname | head -1)

        if [ -z "$LATEST_TAG" ]; then
            echo "Warning: No version tags found. Using all commits from the beginning." >&2
            COMMIT_RANGE="HEAD"
        else
            COMMIT_RANGE="$LATEST_TAG..HEAD"
            echo "Generating changelog from commits since tag: $LATEST_TAG to current changes" >&2
        fi
    elif [ -z "$start_tag" ]; then
        # No start tag but end tag provided - get all commits from beginning to end_tag
        COMMIT_RANGE="$end_tag"
        echo "Generating changelog from all commits up to tag: $end_tag" >&2
    elif [ -z "$end_tag" ]; then
        # No end tag, use HEAD
        COMMIT_RANGE="$start_tag..HEAD"
        echo "Generating changelog from commits between $start_tag and HEAD" >&2
    else
        COMMIT_RANGE="$start_tag..$end_tag"
        echo "Generating changelog from commits between $start_tag and $end_tag" >&2
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
                    DESCRIPTION=$(capitalize_first_letter "$DESCRIPTION")

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
                    if [[ "$MESSAGE" =~ ^(add|new|create).*(feature|function|capability) ]] ||
                        [[ "$MESSAGE" =~ ^(improve|enhance|update).*(UI|user|interface|performance) ]] ||
                        [[ "$MESSAGE" =~ ^(fix|resolve|correct).*(bug|issue|problem|error) ]]; then

                        MESSAGE=$(capitalize_first_letter "$MESSAGE")

                        if [[ "$MESSAGE" =~ ^(Add|New|Create) ]]; then
                            if [ -z "$ADDED" ]; then
                                ADDED="- $MESSAGE"
                            else
                                ADDED="$ADDED\n- $MESSAGE"
                            fi
                        elif [[ "$MESSAGE" =~ ^(Fix|Resolve|Correct) ]]; then
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
    done < <(git log --oneline --no-merges "$COMMIT_RANGE")

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

# Function to generate changelog for all versions
generate_all_versions_changelog() {
    cd "$PROJECT_ROOT"

    echo "Generating changelog for all historical versions..."

    # Get all tags sorted by version
    mapfile -t ALL_TAGS < <(git tag --sort=version:refname)

    if [ ${#ALL_TAGS[@]} -eq 0 ]; then
        echo "No version tags found in repository."
        return 1
    fi

    echo "Found ${#ALL_TAGS[@]} version tags: ${ALL_TAGS[*]}"

    # Start with the changelog header
    cat >"$MAIN_CHANGELOG" <<EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

EOF

    # Create changelog directory if it doesn't exist
    mkdir -p "$CHANGELOG_DIR"

    # Generate changelog for each version (newest first)
    for ((i = ${#ALL_TAGS[@]} - 1; i >= 0; i--)); do
        current_tag="${ALL_TAGS[$i]}"
        previous_tag=""

        if [ $i -gt 0 ]; then
            previous_tag="${ALL_TAGS[$((i - 1))]}"
        fi

        echo "Processing version $current_tag..."

        # Get the tag date
        tag_date=$(git log -1 --format=%ai "$current_tag" | cut -d' ' -f1)

        # Get version code from pubspec.yaml at this tag
        version_code=""
        if git show "$current_tag:src/pubspec.yaml" >/dev/null 2>&1; then
            version_line=$(git show "$current_tag:src/pubspec.yaml" | grep "^version:" | head -1)
            if [[ "$version_line" =~ ^version:\ [0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)$ ]]; then
                version_code="${BASH_REMATCH[1]}"
            fi
        fi

        # Generate changelog content for this version
        if [ -n "$previous_tag" ]; then
            changelog_content=$(generate_changelog_from_commits "$previous_tag" "$current_tag")
        else
            # First version - get all commits up to this tag
            changelog_content=$(generate_changelog_from_commits "" "$current_tag")
        fi

        # Clean version number (remove 'v' prefix if present)
        clean_version="${current_tag#v}"

        # Add to main changelog
        echo "## [$clean_version] - $tag_date" >>"$MAIN_CHANGELOG"
        echo "" >>"$MAIN_CHANGELOG"

        if [ -n "$changelog_content" ]; then
            echo -e "$changelog_content" >>"$MAIN_CHANGELOG"
        else
            echo "### Changed" >>"$MAIN_CHANGELOG"
            echo "- Various behind-the-scenes improvements and optimizations for a better experience" >>"$MAIN_CHANGELOG"
        fi

        echo "" >>"$MAIN_CHANGELOG"

        # Create Fastlane changelog if we have version code
        if [ -n "$version_code" ] && [ -n "$changelog_content" ]; then
            fastlane_content=$(convert_to_fastlane_format "$changelog_content")
            if [ -n "$fastlane_content" ]; then
                fastlane_file="$CHANGELOG_DIR/$version_code.txt"
                echo -e "$fastlane_content" >"$fastlane_file"

                # Check file size (F-Droid limit: 500 bytes)
                file_size=$(wc -c <"$fastlane_file")
                if [ "$file_size" -gt 500 ]; then
                    echo "  ⚠️  Warning: Changelog for version code $version_code is $file_size bytes (exceeds 500 byte limit)"
                    # Truncate to fit limit - keep first few items and add "..."
                    truncated_content=$(echo -e "$fastlane_content" | head -c 450)
                    # Find the last complete line
                    last_newline=$(echo "$truncated_content" | grep -o ".*" | tail -1)
                    echo -e "$last_newline\n• ..." >"$fastlane_file"
                    file_size=$(wc -c <"$fastlane_file")
                fi

                echo "  📱 Created Fastlane changelog: $version_code.txt ($file_size bytes)"
            fi
        elif [ -n "$version_code" ]; then
            # Create minimal Fastlane changelog even if no user-facing changes
            fastlane_file="$CHANGELOG_DIR/$version_code.txt"
            echo "• Various behind-the-scenes improvements and optimizations for a better experience" >"$fastlane_file"
            echo "  📱 Created minimal Fastlane changelog: $version_code.txt"
        fi
    done

    # Count Fastlane changelogs created
    fastlane_count=$(find "$CHANGELOG_DIR" -name "*.txt" -type f 2>/dev/null | wc -l)

    echo "✅ Generated complete changelog for all ${#ALL_TAGS[@]} versions"
    echo "📱 Created $fastlane_count Fastlane changelog files"
}

# Function to convert Keep a Changelog format to simple bullet points for Fastlane
convert_to_fastlane_format() {
    local keep_a_changelog_content="$1"

    # Convert to fastlane format and limit to stay under 500 bytes
    # Extract lines that start with "- " (bullet points), ignoring section headers
    local fastlane_content
    fastlane_content=$(echo -e "$keep_a_changelog_content" |
        grep "^- " |
        sed 's/^- /• /' |
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                # Extract the content after the bullet point
                content="${line#• }"
                # Capitalize first letter and add bullet point back
                echo "• $(capitalize_first_letter "$content")"
            fi
        done)

    # If no bullet points found, return empty (should not happen with fallback)
    if [ -z "$fastlane_content" ]; then
        echo ""
        return 1
    fi

    # Check if content exceeds 500 bytes and truncate if needed
    local content_size
    content_size=$(echo -e "$fastlane_content" | wc -c)

    if [ "$content_size" -gt 450 ]; then
        # Take only first few items to stay under limit
        local truncated_content=""
        local current_size=0

        echo -e "$fastlane_content" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                local line_size=${#line}
                local new_size=$((current_size + line_size + 1)) # +1 for newline

                if [ "$new_size" -lt 450 ]; then
                    if [ -z "$truncated_content" ]; then
                        truncated_content="$line"
                    else
                        truncated_content="$truncated_content\n$line"
                    fi
                    current_size=$new_size
                else
                    break
                fi
            fi
        done

        # Use head to get first 6 items max to stay under 500 bytes
        echo -e "$fastlane_content" | head -6
    else
        echo -e "$fastlane_content"
    fi
}

# Function to create or update main CHANGELOG.md
update_main_changelog() {
    local version="$1"
    local changelog_content="$2"
    local date
    date=$(date +%Y-%m-%d)

    local new_entry="## [$version] - $date\n\n$changelog_content"

    if [ ! -f "$MAIN_CHANGELOG" ]; then
        # Create new CHANGELOG.md
        cat >"$MAIN_CHANGELOG" <<EOF
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
            ' "$MAIN_CHANGELOG" >"$MAIN_CHANGELOG.tmp"
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
            ' "$MAIN_CHANGELOG" >"$MAIN_CHANGELOG.tmp"
            mv "$MAIN_CHANGELOG.tmp" "$MAIN_CHANGELOG"
        fi
    fi
}

# Function to extract changelog content from CHANGELOG.md for a specific version
extract_changelog_from_main() {
    local version="$1"

    if [ ! -f "$MAIN_CHANGELOG" ]; then
        echo "CHANGELOG.md not found"
        return 1
    fi

    # Extract content between version section and next version section
    local content
    content=$(awk "
        /^## \[$version\]/ { found=1; next }
        found && /^## \[/ { found=0 }
        found && /^###/ { print }
        found && /^- / { print }
    " "$MAIN_CHANGELOG")

    if [ -n "$content" ]; then
        echo -e "$content"
    else
        echo "No content found for version $version in CHANGELOG.md"
        return 1
    fi
}

# Function to get version from version code using git tags
get_version_from_code() {
    local version_code="$1"

    cd "$PROJECT_ROOT"

    # Search through git tags for matching version code
    for tag in $(git tag --sort=-version:refname); do
        if git show "$tag:src/pubspec.yaml" >/dev/null 2>&1; then
            local version_line
            version_line=$(git show "$tag:src/pubspec.yaml" | grep "^version:" | head -1)
            if [[ "$version_line" =~ version:\ [0-9]+\.[0-9]+\.[0-9]+\+([0-9]+) ]]; then
                local tag_version_code="${BASH_REMATCH[1]}"
                if [ "$tag_version_code" = "$version_code" ]; then
                    # Clean version number (remove 'v' prefix if present)
                    echo "${tag#v}"
                    return 0
                fi
            fi
        fi
    done

    echo "Unknown version for code $version_code"
    return 1
}

# Handle --all-versions flag
if [ "$ALL_VERSIONS" = true ]; then
    echo "🔄 Generating changelog for all historical versions..."
    echo ""

    if [ "$AUTO_ACCEPT" = false ]; then
        echo "This will completely regenerate CHANGELOG.md with all historical versions."
        echo ""
        read -r -p "Do you want to continue? (y/N): " confirm

        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            exit 1
        fi
    fi

    # Generate changelog for all versions
    generate_all_versions_changelog

    echo "✅ Complete changelog generated successfully!"
    echo "📝 Main changelog: $MAIN_CHANGELOG"
    echo "📱 Fastlane directory: $CHANGELOG_DIR"

    # Show statistics
    version_count=$(grep -c "^## \[" "$MAIN_CHANGELOG")
    fastlane_count=$(find "$CHANGELOG_DIR" -name "*.txt" -type f 2>/dev/null | wc -l)
    echo "📊 Total versions documented: $version_count"
    echo "📊 Fastlane changelogs created: $fastlane_count"

    exit 0
fi

# Regular changelog generation (single version)
if [ -z "$CHANGELOG_TEXT" ]; then
    echo "No changelog text provided. Generating changelog for current version from pubspec.yaml..."

    # For the current version, we use pubspec.yaml version and generate changelog from last tag to HEAD
    if [ "$VERSION_CODE" = "$CURRENT_VERSION_CODE" ]; then
        echo "Generating changelog for current version $CURRENT_VERSION (code: $VERSION_CODE)..."
        echo "Checking for changes since last git tag..."

        CHANGELOG_CONTENT=$(generate_changelog_from_commits)

        if [ -z "$CHANGELOG_CONTENT" ]; then
            echo "No user-facing changes found since last version."
            echo "All commits appear to be internal changes (CI, build, tests, etc.)"
            CHANGELOG_CONTENT="### Changed\n- Internal improvements and maintenance"
        fi
    else
        # For historical versions, try to find the corresponding git tag
        if TARGET_VERSION=$(get_version_from_code "$VERSION_CODE") && [ "$TARGET_VERSION" != "Unknown version for code $VERSION_CODE" ]; then
            echo "Found existing version $TARGET_VERSION for code $VERSION_CODE"

            # Try to extract from existing CHANGELOG.md
            if CHANGELOG_CONTENT=$(extract_changelog_from_main "$TARGET_VERSION") && [ -n "$CHANGELOG_CONTENT" ]; then
                echo "Using existing changelog content from CHANGELOG.md for version $TARGET_VERSION"
            else
                echo "No existing changelog found, generating from commit messages..."
                CHANGELOG_CONTENT=$(generate_changelog_from_commits)

                if [ -z "$CHANGELOG_CONTENT" ]; then
                    echo "No user-facing changes found since last version."
                    echo "All commits appear to be internal changes (CI, build, tests, etc.)"
                    CHANGELOG_CONTENT="### Changed\n- Internal improvements and maintenance"
                fi
            fi
        else
            echo "Generating from commit messages for version code $VERSION_CODE..."
            CHANGELOG_CONTENT=$(generate_changelog_from_commits)

            if [ -z "$CHANGELOG_CONTENT" ]; then
                echo "No user-facing changes found since last version."
                echo "All commits appear to be internal changes (CI, build, tests, etc.)"
                CHANGELOG_CONTENT="### Changed\n- Internal improvements and maintenance"
            fi
        fi
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
        read -r -p "Do you want to use this generated changelog? (y/N): " confirm

        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Usage: $0 [version_code] \"changelog text\" [--auto] [--all-versions]"
            echo "Current version code: $CURRENT_VERSION_CODE"
            echo "Current version: $CURRENT_VERSION"
            echo ""
            echo "Examples:"
            printf '  %s 31 "• New feature added\n• Bug fixes\n• Performance improvements"\n' "$0"
            echo "  $0 --auto                    # Auto-generate changelog for current version"
            echo "  $0 --all-versions --auto     # Generate complete historical changelog"
            exit 1
        fi

        CHANGELOG_TEXT="$FASTLANE_CHANGELOG"
    fi

    # Update main CHANGELOG.md only for current version
    if [ "$VERSION_CODE" = "$CURRENT_VERSION_CODE" ]; then
        echo "Updating main CHANGELOG.md for current version $CURRENT_VERSION..."
        update_main_changelog "$CURRENT_VERSION" "$CHANGELOG_CONTENT"
        echo "✅ Updated $MAIN_CHANGELOG"
    else
        echo "Skipping CHANGELOG.md update for historical version $TARGET_VERSION"
    fi

else
    # Manual changelog provided - create a simple Keep a Changelog entry
    # Capitalize each item in the manual changelog
    CAPITALIZED_ITEMS=$(echo -e "$CHANGELOG_TEXT" | sed 's/^• /- /g' | while IFS= read -r line; do
        if [[ "$line" =~ ^-\ (.+)$ ]]; then
            content="${BASH_REMATCH[1]}"
            echo "- $(capitalize_first_letter "$content")"
        elif [ -n "$line" ]; then
            echo "- $(capitalize_first_letter "$line")"
        fi
    done)
    MANUAL_CONTENT="### Changed\n$CAPITALIZED_ITEMS"
    update_main_changelog "$CURRENT_VERSION" "$MANUAL_CONTENT"
    echo "✅ Updated $MAIN_CHANGELOG with manual changelog"
fi

CHANGELOG_FILE="$CHANGELOG_DIR/$VERSION_CODE.txt"

# Create changelog directory if it doesn't exist
mkdir -p "$CHANGELOG_DIR"

# Create changelog file
echo -e "$CHANGELOG_TEXT" >"$CHANGELOG_FILE"

# Check file size (F-Droid limit: 500 bytes)
FILE_SIZE=$(wc -c <"$CHANGELOG_FILE")
if [ "$FILE_SIZE" -gt 500 ]; then
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
