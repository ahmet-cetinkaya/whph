#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

trap 'acore_log_error "F-Droid CI failed!"; exit 1' ERR

acore_log_header "F-Droid CI Test"

cd src/android/fdroid

acore_log_info "Setting up F-Droid environment..."
python -m venv .fdroid-venv
source .fdroid-venv/bin/activate
pip install --upgrade pip
pip install fdroidserver androguard
acore_log_success "F-Droid environment setup complete"

acore_log_section "Checking metadata syntax"
fdroid readmeta
acore_log_success "fdroid readmeta passed"

acore_log_section "Cleaning up metadata"
fdroid rewritemeta me.ahmetcetinkaya.whph
acore_log_success "fdroid rewritemeta passed"

acore_log_section "Filling automated fields"
fdroid checkupdates me.ahmetcetinkaya.whph
acore_log_success "fdroid checkupdates passed"

acore_log_section "Running F-Droid lint"
fdroid lint me.ahmetcetinkaya.whph
acore_log_success "fdroid lint passed"

acore_log_section "Building F-Droid repository"
fdroid build -v -l me.ahmetcetinkaya.whph
acore_log_success "fdroid build passed"
