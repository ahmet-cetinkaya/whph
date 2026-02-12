#!/bin/bash

# Version bump script for WHPH project
# Updates version in pubspec.yaml, app_info.dart, installer.iss files and generates changelog

set -e

# Source universal logger from acore-scripts submodule
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOGGER_FILE="$PROJECT_ROOT/packages/acore-scripts/src/logger.sh"

# shellcheck source=../packages/acore-scripts/src/logger.sh
source "$LOGGER_FILE"

# Check if argument is provided
if [ $# -eq 0 ]; then
    acore_log_error "Usage: $0 [major|minor|patch]"
    exit 1
fi

BUMP_TYPE=$1

# Validate bump type
if [[ "$BUMP_TYPE" != "major" && "$BUMP_TYPE" != "minor" && "$BUMP_TYPE" != "patch" ]]; then
    print_error "Invalid bump type. Use 'major', 'minor', or 'patch'"
    exit 1
fi

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# File paths
PUBSPEC_FILE="$PROJECT_ROOT/src/pubspec.yaml"
APP_INFO_FILE="$PROJECT_ROOT/src/lib/core/domain/shared/constants/app_info.dart"
INSTALLER_FILE="$PROJECT_ROOT/src/windows/setup-wizard/installer.iss"

# Extract current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | sed 's/+.*//')

echo "Current version: $CURRENT_VERSION"

# Split version into components
IFS='.' read -r -a VERSION_PARTS <<<"$CURRENT_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

acore_log_info "Current: $MAJOR.$MINOR.$PATCH"

# Bump version based on type
case $BUMP_TYPE in
"major")
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
"minor")
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
"patch")
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
acore_log_info "New version: $NEW_VERSION"

# Get current build number from pubspec.yaml
CURRENT_BUILD=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/.*+//')
NEW_BUILD=$((CURRENT_BUILD + 1))

# Update pubspec.yaml
acore_log_info "Updating $PUBSPEC_FILE..."
sed -i "s/^version:.*/version: $NEW_VERSION+$NEW_BUILD/" "$PUBSPEC_FILE"

# Update app_info.dart
echo "Updating $APP_INFO_FILE..."
sed -i "s/static const String version = \".*\";/static const String version = \"$NEW_VERSION\";/" "$APP_INFO_FILE"
echo "Updating build number in $APP_INFO_FILE..."
sed -i "s/static const String buildNumber = \".*\";/static const String buildNumber = \"$NEW_BUILD\";/" "$APP_INFO_FILE"

# Update installer.iss
echo "Updating $INSTALLER_FILE..."
sed -i "s/AppVersion=.*/AppVersion=$NEW_VERSION/" "$INSTALLER_FILE"

# Generate changelog
acore_log_info "Generating changelog..."
cd "$PROJECT_ROOT"
bash scripts/create_changelog.sh "$NEW_BUILD" --auto

# Ask for confirmation before git operations
echo ""
echo "Files have been updated and changelog generated."
echo "The following git operations will be performed:"
echo "  1. Commit main repository changes (version files + changelog)"
echo "  2. Create version tag: v$NEW_VERSION"
echo ""
read -p "Do you want to proceed with git operations? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Git operations cancelled. Files have been updated but not committed."
    echo "You can manually commit the changes later or run the script again."
    exit 0
fi

# Git operations - Create version bump commit first
echo "Creating version bump commit..."

# Stage changes in the main repository
echo "Staging main repository changes..."
git add "$PUBSPEC_FILE" "$APP_INFO_FILE" "$INSTALLER_FILE" "CHANGELOG.md"
for d in fastlane/metadata/android/*/; do
    git add "${d}changelogs"

done
git commit -m "chore: update app version to $NEW_VERSION"

# Create version tag
git tag -a "v$NEW_VERSION" -m "Version $NEW_VERSION"

echo "Version bump completed successfully!"
echo "Updated files:"
echo "  - $PUBSPEC_FILE (version: $NEW_VERSION+$NEW_BUILD)"
echo "  - $APP_INFO_FILE (version: $NEW_VERSION)"
echo "  - $INSTALLER_FILE (version: $NEW_VERSION)"
echo "  - CHANGELOG.md (generated for version $NEW_VERSION)"
echo "  - fastlane/metadata/android/*/changelogs/ (generated for version code $NEW_BUILD)"
echo ""

# Git operations completed
echo "Git operations completed:"
echo "  - Created version bump commit"
echo "  - Created version tag: v$NEW_VERSION"
echo ""
echo "To push changes and tags to remote:"
echo "  git push && git push --tags"
echo ""
echo "This will push main repository changes and tags."
