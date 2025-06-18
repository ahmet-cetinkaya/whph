#!/bin/bash

# Version bump script for WHPH project
# Updates version in pubspec.yaml, app_info.dart, and installer.iss files

set -e

# Check if argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [major|minor|patch]"
    exit 1
fi

BUMP_TYPE=$1

# Validate bump type
if [[ "$BUMP_TYPE" != "major" && "$BUMP_TYPE" != "minor" && "$BUMP_TYPE" != "patch" ]]; then
    echo "Error: Invalid bump type. Use 'major', 'minor', or 'patch'"
    exit 1
fi

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# File paths
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"
APP_INFO_FILE="$PROJECT_ROOT/lib/src/core/domain/shared/constants/app_info.dart"
INSTALLER_FILE="$PROJECT_ROOT/windows/installer.iss"

# Extract current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | sed 's/+.*//')

echo "Current version: $CURRENT_VERSION"

# Split version into components
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

echo "Current: $MAJOR.$MINOR.$PATCH"

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
echo "New version: $NEW_VERSION"

# Get current build number from pubspec.yaml
CURRENT_BUILD=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/.*+//')
NEW_BUILD=$((CURRENT_BUILD + 1))

# Update pubspec.yaml
echo "Updating $PUBSPEC_FILE..."
sed -i "s/^version:.*/version: $NEW_VERSION+$NEW_BUILD/" "$PUBSPEC_FILE"

# Update app_info.dart
echo "Updating $APP_INFO_FILE..."
sed -i "s/static const String version = \".*\";/static const String version = \"$NEW_VERSION\";/" "$APP_INFO_FILE"

# Update installer.iss
echo "Updating $INSTALLER_FILE..."
sed -i "s/AppVersion=.*/AppVersion=$NEW_VERSION/" "$INSTALLER_FILE"

echo "Version bump completed successfully!"
echo "Updated files:"
echo "  - $PUBSPEC_FILE (version: $NEW_VERSION+$NEW_BUILD)"
echo "  - $APP_INFO_FILE (version: $NEW_VERSION)"
echo "  - $INSTALLER_FILE (version: $NEW_VERSION)"
echo ""
echo "Don't forget to commit these changes!"
