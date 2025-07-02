#!/bin/bash

# Version bump script for WHPH project
# Updates version in pubspec.yaml, app_info.dart, installer.iss files and generates changelog

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
INSTALLER_FILE="$PROJECT_ROOT/windows/setup-wizard/installer.iss"
FDROID_METADATA_FILE="$PROJECT_ROOT/android/fdroid/metadata/me.ahmetcetinkaya.whph.yml"

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

# First update F-Droid metadata without commit hash
echo "Updating $FDROID_METADATA_FILE (initial)..."
sed -i "s/versionName: .*/versionName: $NEW_VERSION/" "$FDROID_METADATA_FILE"
sed -i "s/versionCode: .*/versionCode: $NEW_BUILD/" "$FDROID_METADATA_FILE"
sed -i "s/CurrentVersion: .*/CurrentVersion: $NEW_VERSION+$NEW_BUILD/" "$FDROID_METADATA_FILE"
sed -i "s/CurrentVersionCode: .*/CurrentVersionCode: $NEW_BUILD/" "$FDROID_METADATA_FILE"
sed -i "s/--build-name=.*/--build-name=$NEW_VERSION+$NEW_BUILD/" "$FDROID_METADATA_FILE"

# Generate changelog
echo "Generating changelog..."
cd "$PROJECT_ROOT"
bash scripts/create_changelog.sh "$NEW_BUILD" --auto

# Git operations - Create version bump commit first
echo "Creating version bump commit..."

# First, stage changes in the F-Droid submodule
echo "Staging F-Droid metadata changes in submodule..."
cd "$PROJECT_ROOT/android/fdroid"
git add "metadata/me.ahmetcetinkaya.whph.yml"
git commit -m "feat(me.ahmetcetinkaya.whph): update app version to $NEW_VERSION"
cd "$PROJECT_ROOT"

# Then, stage changes in the main repository (including submodule update)
echo "Staging main repository changes..."
git add "$PUBSPEC_FILE" "$APP_INFO_FILE" "$INSTALLER_FILE" "android/fdroid" "CHANGELOG.md" "fastlane/metadata/android/en-US/changelogs/"
git commit -m "chore: update app version to $NEW_VERSION"

# Get the commit hash of the version bump commit
VERSION_COMMIT=$(git rev-parse HEAD)

# Now update F-Droid metadata with the correct commit hash
echo "Updating F-Droid metadata with commit hash..."
cd "$PROJECT_ROOT/android/fdroid"
sed -i "s/commit: .*/commit: $VERSION_COMMIT/" "metadata/me.ahmetcetinkaya.whph.yml"
git add "metadata/me.ahmetcetinkaya.whph.yml"
git commit -m "build(me.ahmetcetinkaya.whph): update commit hash for F-Droid build"
cd "$PROJECT_ROOT"

# Update the submodule reference in main repo
git add "android/fdroid"
git commit -m "chore: update F-Droid submodule with commit hash"

# Create version tag
git tag -a "v$NEW_VERSION" -m "Version $NEW_VERSION"

echo "Version bump completed successfully!"
echo "Updated files:"
echo "  - $PUBSPEC_FILE (version: $NEW_VERSION+$NEW_BUILD)"
echo "  - $APP_INFO_FILE (version: $NEW_VERSION)"
echo "  - $INSTALLER_FILE (version: $NEW_VERSION)"
echo "  - $FDROID_METADATA_FILE (versionName: $NEW_VERSION, versionCode: $NEW_BUILD, commit: $VERSION_COMMIT)"
echo "  - CHANGELOG.md (generated for version $NEW_VERSION)"
echo "  - fastlane/metadata/android/en-US/changelogs/ (generated for version code $NEW_BUILD)"
echo ""

# Git operations completed
echo "Git operations completed:"
echo "  - Created version bump commit: $VERSION_COMMIT"
echo "  - Updated F-Droid metadata with correct commit hash"
echo "  - Created version tag: v$NEW_VERSION"
echo ""
echo "To push changes and tags to remote:"
echo "  rps version:push"
echo ""
echo "This will:"
echo "  1. Push F-Droid submodule changes"
echo "  2. Push main repository changes and tags"
