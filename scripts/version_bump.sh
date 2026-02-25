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

# Define all version-related files
PUBSPEC_FILE="$PROJECT_ROOT/src/pubspec.yaml"
APP_INFO_FILE="$PROJECT_ROOT/src/lib/core/domain/shared/constants/app_info.dart"
INSTALLER_FILE="$PROJECT_ROOT/packaging/inno-setup/installer.iss"
FLATPAK_MANIFEST_FILE="$PROJECT_ROOT/packaging/flatpak/flatpak-flutter.yaml"
FLATHUB_MANIFEST_FILE="$PROJECT_ROOT/packaging/flatpak/flathub/me.ahmetcetinkaya.whph.yaml"
METAINFO_FILE="$PROJECT_ROOT/src/linux/share/metainfo/me.ahmetcetinkaya.whph.metainfo.xml"

# Files that are handled by release.yml - skip these
AUR_PKGBUILD_FILE="$PROJECT_ROOT/packaging/aur/PKGBUILD"
AUR_SRCINFO_FILE="$PROJECT_ROOT/packaging/aur/.SRCINFO"
NIX_FLAKE_FILE="$PROJECT_ROOT/packaging/nix/flake.nix"

# Get current version from pubspec.yaml
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

# ============================================
# Update version in all relevant files
# ============================================

acore_log_section "Updating files"

# Update pubspec.yaml
acore_log_info "Updating $PUBSPEC_FILE..."
sed -i "s/^version:.*/version: $NEW_VERSION+$NEW_BUILD/" "$PUBSPEC_FILE"

# Update app_info.dart
acore_log_info "Updating $APP_INFO_FILE..."
sed -i "s/static const String version = \".*\";/static const String version = \"$NEW_VERSION\";/" "$APP_INFO_FILE"
acore_log_info "Updating build number in $APP_INFO_FILE..."
sed -i "s/static const String buildNumber = \".*\";/static const String buildNumber = \"$NEW_BUILD\";/" "$APP_INFO_FILE"

# Update Inno Setup installer
acore_log_info "Updating $INSTALLER_FILE..."
sed -i "s/AppVersion=.*/AppVersion=$NEW_VERSION/" "$INSTALLER_FILE"

# Update Flatpak manifest (flatpak-flutter.yaml)
acore_log_info "Updating $FLATPAK_MANIFEST_FILE..."
sed -i "s/tag: v.*/tag: v$NEW_VERSION/" "$FLATPAK_MANIFEST_FILE"

# ============================================
# Skip AUR and Nix - handled by release.yml
# ============================================

acore_log_section "Skipping externally managed files"
acore_log_info "Skipping $AUR_PKGBUILD_FILE - handled by .github/workflows/release.yml (update-aur job)"
acore_log_info "Skipping $AUR_SRCINFO_FILE - handled by .github/workflows/release.yml (update-aur job)"
acore_log_info "Skipping $NIX_FLAKE_FILE - handled by .github/workflows/release.yml (update-nix job)"
acore_log_warning "Note: AUR and Nix packages are updated automatically by the release workflow after publishing."

# ============================================
# Generate changelog
# ============================================

acore_log_section "Generating changelog"
cd "$PROJECT_ROOT"
bash packages/acore-scripts/src/generate_changelog.sh "$NEW_VERSION" -y

# Extract changelog content for the new version from CHANGELOG.md
# This extracts the content between the version header and the next version header
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"
VERSION_CHANGELOG=""

if [ -f "$CHANGELOG_FILE" ]; then
    # Extract content for the new version (between ## [X.Y.Z] and the next ## [ header)
    VERSION_CHANGELOG=$(sed -n "/^## \[$NEW_VERSION\]/,/^## \[/{ /^## \[$NEW_VERSION\]/d; /^## \[/d; p; }" "$CHANGELOG_FILE" | sed '/^$/d' | head -20)
    
    if [ -n "$VERSION_CHANGELOG" ]; then
        acore_log_info "Extracted changelog for version $NEW_VERSION from CHANGELOG.md"
    else
        acore_log_warning "Could not extract changelog for version $NEW_VERSION, will generate from commits"
    fi
fi

# Create fastlane changelog with the extracted content
if [ -n "$VERSION_CHANGELOG" ]; then
    # Format the changelog for fastlane:
    # - Remove markdown headers (### and ##)
    # - Convert markdown bullets to simple format
    # - Remove empty lines
    FORMATTED_CHANGELOG=$(echo "$VERSION_CHANGELOG" | sed '/^### /d' | sed '/^## /d' | sed 's/^\- /• /g' | sed 's/^\* /• /g')
    bash scripts/create_fastlane_changelog.sh "$NEW_BUILD" "$FORMATTED_CHANGELOG" --auto
else
    bash scripts/create_fastlane_changelog.sh "$NEW_BUILD" --auto
fi

# ============================================
# Update metainfo.xml with changelog content
# ============================================

acore_log_info "Updating $METAINFO_FILE..."
# Update screenshot URLs from old version to new version
sed -i "s|/v$CURRENT_VERSION/|/v$NEW_VERSION/|g" "$METAINFO_FILE"

# Get current date in YYYY-MM-DD format
RELEASE_DATE=$(date +%Y-%m-%d)

# Convert changelog content to HTML list items for metainfo.xml
# Extract bullet points and convert to <li> elements
if [ -n "$VERSION_CHANGELOG" ]; then
    # Process changelog: remove headers, convert bullets to <li> tags
    HTML_LIST_ITEMS=$(echo "$VERSION_CHANGELOG" | \
        sed '/^### /d' | \
        sed '/^## /d' | \
        sed 's/^\- \(.*\)$/          <li>\1<\/li>/' | \
        sed 's/^\* \(.*\)$/          <li>\1<\/li>/')
else
    HTML_LIST_ITEMS="          <li>See CHANGELOG.md for details</li>"
fi

# Create the new release entry with proper indentation
NEW_RELEASE_ENTRY="    <release version=\"$NEW_VERSION\" date=\"$RELEASE_DATE\">
      <url type=\"details\">https://github.com/ahmet-cetinkaya/whph/blob/v$NEW_VERSION/CHANGELOG.md</url>
      <description>
        <ul>
$HTML_LIST_ITEMS
        </ul>
      </description>
    </release>"

# Insert the new release entry after the <releases> tag
# Using a temporary file approach for better compatibility
TEMP_FILE=$(mktemp)
awk -v new_release="$NEW_RELEASE_ENTRY" '
    /<releases>/ {
        print $0
        print new_release
        next
    }
    { print }
' "$METAINFO_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$METAINFO_FILE"

acore_log_info "Added new release entry for version $NEW_VERSION with changelog content"

# ============================================
# Git operations
# ============================================

acore_log_info "Files have been updated and changelog generated."
acore_log_info "The following git operations will be performed:"
acore_log_info "  1. Commit main repository changes (version files + changelog)"
acore_log_info "  2. Create version tag: v$NEW_VERSION"
acore_log_info "  3. Update Flathub manifest with new version and commit hash"
echo ""
read -p "Do you want to proceed with git operations? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    acore_log_warning "Git operations cancelled. Files have been updated but not committed."
    acore_log_warning "You can manually commit the changes later or run the script again."
    exit 0
fi

acore_log_section "Git operations"

# Stage and commit main repository changes
acore_log_info "Staging main repository changes..."
git add "$PUBSPEC_FILE" "$APP_INFO_FILE" "$INSTALLER_FILE" "$FLATPAK_MANIFEST_FILE" "$METAINFO_FILE" "CHANGELOG.md"
git add "fastlane/metadata/android/*/changelogs/*.txt"
git commit -m "chore: update app version to $NEW_VERSION"

# Create git tag
acore_log_info "Creating version tag v$NEW_VERSION..."
git tag -s "v$NEW_VERSION" -m "Version $NEW_VERSION"

# ============================================
# Post-commit: Update Flathub manifest (submodule)
# ============================================

acore_log_section "Post-commit: Updating Flathub manifest"

# Get the commit hash for the new tag
TAG_COMMIT_HASH=$(git rev-parse "v$NEW_VERSION")

if [[ -n "$TAG_COMMIT_HASH" ]]; then
    acore_log_info "Updating $FLATHUB_MANIFEST_FILE with version $NEW_VERSION and commit $TAG_COMMIT_HASH..."
    
    # Update the tag version in flathub manifest
    sed -i "s/tag: v.*/tag: v$NEW_VERSION/" "$FLATHUB_MANIFEST_FILE"
    
    # Update the commit hash in flathub manifest
    # The commit line is typically right after the tag line
    sed -i "/tag: v$NEW_VERSION/,/commit:/ s/commit: .*/commit: $TAG_COMMIT_HASH/" "$FLATHUB_MANIFEST_FILE"
    
    acore_log_success "Flathub manifest updated with:"
    acore_log_success "  - Version: v$NEW_VERSION"
    acore_log_success "  - Commit: $TAG_COMMIT_HASH"
    
    # Commit changes in the flathub submodule
    acore_log_info "Committing changes in flathub submodule..."
    cd "$PROJECT_ROOT/packaging/flatpak/flathub"
    git add me.ahmetcetinkaya.whph.yaml
    git commit -m "feat: bump whph source version to v$NEW_VERSION"
    FLATHUB_SUBMODULE_COMMIT=$(git rev-parse HEAD)
    cd "$PROJECT_ROOT"
    
    acore_log_success "Flathub submodule commit created: $FLATHUB_SUBMODULE_COMMIT"
    
    # Commit the submodule pointer update in the root repository
    acore_log_info "Updating flathub submodule pointer in root repository..."
    git add packaging/flatpak/flathub
    git commit -m "chore(flatpak): update flathub submodule to v$NEW_VERSION"
    
    acore_log_success "Root repository updated with new flathub submodule pointer"
else
    acore_log_error "Failed to get commit hash for tag v$NEW_VERSION"
    acore_log_warning "Flathub manifest not updated. Please update manually."
fi

# ============================================
# Summary
# ============================================

acore_log_success "Version bump completed successfully!"
acore_log_info "Updated files:"
acore_log_info "  - $PUBSPEC_FILE (version: $NEW_VERSION+$NEW_BUILD)"
acore_log_info "  - $APP_INFO_FILE (version: $NEW_VERSION, build: $NEW_BUILD)"
acore_log_info "  - $INSTALLER_FILE (version: $NEW_VERSION)"
acore_log_info "  - $FLATPAK_MANIFEST_FILE (tag: v$NEW_VERSION)"
acore_log_info "  - $METAINFO_FILE (screenshots: v$NEW_VERSION, release entry added)"
acore_log_info "  - $FLATHUB_MANIFEST_FILE (tag: v$NEW_VERSION, commit: $TAG_COMMIT_HASH)"
acore_log_info "  - CHANGELOG.md (generated for version $NEW_VERSION)"
acore_log_info "  - fastlane/metadata/android/*/changelogs/ (generated for version code $NEW_BUILD)"

acore_log_success "Git operations completed:"
acore_log_success "  - Created version bump commit"
acore_log_success "  - Created version tag: v$NEW_VERSION"
acore_log_success "  - Updated Flathub manifest and committed in submodule"
acore_log_success "  - Updated flathub submodule pointer in root repository"

acore_log_info "Skipped files (handled by release.yml):"
acore_log_info "  - $AUR_PKGBUILD_FILE"
acore_log_info "  - $AUR_SRCINFO_FILE"
acore_log_info "  - $NIX_FLAKE_FILE"

acore_log_info "To push all changes and tags to remote:"
acore_log_info "  git push && git push --tags"
acore_log_info "  cd packaging/flatpak/flathub && git push origin me.ahmetcetinkaya.whph"
