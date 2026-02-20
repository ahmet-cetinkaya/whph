#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

PUBSPEC_FILE="$PROJECT_ROOT/src/pubspec.yaml"

# Extract current version
CURRENT_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | sed 's/+.*//')

# Avoid "dubious ownership" errors by marking the project as safe for all users
git config --system --add safe.directory '*'

acore_log_header "AUR Package Update"
AUR_DIR="$PROJECT_ROOT/packaging/aur"

if [ ! -d "$AUR_DIR" ]; then
    acore_log_error "AUR directory not found at $AUR_DIR"
    exit 1
fi

acore_log_info "Updating AUR package at $AUR_DIR..."
cd "$AUR_DIR"

# Ensure remote is SSH for pushing
acore_log_info "Setting remote to SSH..."
git remote set-url origin "ssh://aur@aur.archlinux.org/whph-bin.git"

# Ensure we are on master branch
acore_log_info "Ensuring master branch..."
git checkout master || git checkout -b master

# Setup SSH known hosts to prevent interactive prompt
if [ ! -d ~/.ssh ]; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
fi
ssh-keyscan aur.archlinux.org >>~/.ssh/known_hosts

# Update pkgver and pkgrel in PKGBUILD
# We use the current version from pubspec.yaml as the target version
acore_log_info "Setting pkgver to $CURRENT_VERSION in PKGBUILD..."
sed -i "s/^pkgver=.*/pkgver=$CURRENT_VERSION/" PKGBUILD
sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD

acore_log_info "Setting up build user..."
if ! id "builduser" &>/dev/null; then
    useradd -m builduser
fi
chown -R builduser:builduser "$AUR_DIR"

acore_log_info "Updating checksums..."
if ! command -v updpkgsums &>/dev/null; then
    acore_log_error "'updpkgsums' not found. Please install pacman-contrib."
    exit 1
fi

# updpkgsums downloads the source and updates checksums
if sudo -u builduser updpkgsums; then
    acore_log_success "Checksums updated."
else
    acore_log_error "Failed to update checksums. Is the release artifact available?"
    exit 1
fi

acore_log_info "Regenerating .SRCINFO..."
if ! command -v makepkg &>/dev/null; then
    acore_log_error "'makepkg' not found. Please install pacman/base-devel."
    exit 1
fi
sudo -u builduser makepkg --printsrcinfo >.SRCINFO

# Restore ownership to root for Git operations
chown -R root:root "$PROJECT_ROOT"
# Ensure the project root is marked safe after restoring ownership
git config --add safe.directory "$PROJECT_ROOT"

acore_log_section "Git Operations (AUR)"

# Check for changes
if [[ -z $(git status -s) ]]; then
    acore_log_info "No changes to commit."
    exit 0
fi

acore_log_info "Staging AUR changes..."
git add PKGBUILD .SRCINFO

acore_log_info "Committing changes..."
git commit -m "chore: bump version to v$CURRENT_VERSION"

# Only push if we are essentially asked to (implicit in this script usually running in CI or manually for this purpose)
acore_log_info "Pushing changes..."
git pull --rebase
git push

acore_log_success "AUR package updated and pushed successfully."
