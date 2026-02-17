#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

if [ $# -eq 0 ]; then
    acore_log_error "Usage: $0 [major|minor|patch]"
    exit 1
fi

BUMP_TYPE=$1

if [[ "$BUMP_TYPE" != "major" && "$BUMP_TYPE" != "minor" && "$BUMP_TYPE" != "patch" ]]; then
    acore_log_error "Invalid bump type. Use 'major', 'minor', or 'patch'"
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PUBSPEC_FILE="$PROJECT_ROOT/src/pubspec.yaml"
APP_INFO_FILE="$PROJECT_ROOT/src/lib/core/domain/shared/constants/app_info.dart"
INSTALLER_FILE="$PROJECT_ROOT/packaging/inno-setup/installer.iss"

CURRENT_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | sed 's/+.*//')

acore_log_header "Version Bump"
acore_log_info "Current version: $CURRENT_VERSION"

IFS='.' read -r -a VERSION_PARTS <<<"$CURRENT_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

acore_log_info "Current: $MAJOR.$MINOR.$PATCH"

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

CURRENT_BUILD=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/.*+//')
NEW_BUILD=$((CURRENT_BUILD + 1))

acore_log_section "Updating files"
acore_log_info "Updating $PUBSPEC_FILE..."
sed -i "s/^version:.*/version: $NEW_VERSION+$NEW_BUILD/" "$PUBSPEC_FILE"

acore_log_info "Updating $APP_INFO_FILE..."
sed -i "s/static const String version = \".*\";/static const String version = \"$NEW_VERSION\";/" "$APP_INFO_FILE"
acore_log_info "Updating build number in $APP_INFO_FILE..."
sed -i "s/static const String buildNumber = \".*\";/static const String buildNumber = \"$NEW_BUILD\";/" "$APP_INFO_FILE"

acore_log_info "Updating $INSTALLER_FILE..."
sed -i "s/AppVersion=.*/AppVersion=$NEW_VERSION/" "$INSTALLER_FILE"

acore_log_section "Generating changelog"
cd "$PROJECT_ROOT"
bash packages/acore-scripts/src/generate_changelog.sh "$NEW_VERSION" -y
bash scripts/create_fastlane_changelog.sh "$NEW_BUILD" --auto

acore_log_info "Files have been updated and changelog generated."
acore_log_info "The following git operations will be performed:"
acore_log_info "  1. Commit main repository changes (version files + changelog)"
acore_log_info "  2. Create version tag: v$NEW_VERSION"
echo ""
read -p "Do you want to proceed with git operations? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    acore_log_warning "Git operations cancelled. Files have been updated but not committed."
    acore_log_warning "You can manually commit the changes later or run the script again."
    exit 0
fi

acore_log_section "Git operations"
acore_log_info "Staging main repository changes..."
git add "$PUBSPEC_FILE" "$APP_INFO_FILE" "$INSTALLER_FILE" "CHANGELOG.md"
git add "fastlane/metadata/android/*/changelogs/*.txt"
git commit -m "chore: update app version to $NEW_VERSION"

git tag -a "v$NEW_VERSION" -m "Version $NEW_VERSION"

acore_log_success "Version bump completed successfully!"
acore_log_info "Updated files:"
acore_log_info "  - $PUBSPEC_FILE (version: $NEW_VERSION+$NEW_BUILD)"
acore_log_info "  - $APP_INFO_FILE (version: $NEW_VERSION)"
acore_log_info "  - $INSTALLER_FILE (version: $NEW_VERSION)"
acore_log_info "  - CHANGELOG.md (generated for version $NEW_VERSION)"
acore_log_info "  - fastlane/metadata/android/*/changelogs/ (generated for version code $NEW_BUILD)"

acore_log_success "Git operations completed:"
acore_log_success "  - Created version bump commit"
acore_log_success "  - Created version tag: v$NEW_VERSION"
acore_log_info "To push changes and tags to remote:"
acore_log_info "  git push && git push --tags"
