#!/bin/bash

# Flatpak Validation Script
# This script validates Flatpak manifests, desktop files, and AppStream metadata
# adhering to Flathub rules and project guidelines.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

ERRORS=0
WARNINGS=0

acore_log_header "Flatpak Packaging Validation"

# Check dependencies
for cmd in flatpak appstreamcli desktop-file-validate jq; do
	if ! command -v "$cmd" &>/dev/null; then
		acore_log_warning "\"$cmd\" is not installed. Some validations or parsing will be degraded/skipped."
	fi
done

HAS_FLATPAK_BUILDER_LINT=false
if command -v flatpak &>/dev/null && flatpak run --command=flatpak-builder-lint org.flatpak.Builder --help &>/dev/null; then
	HAS_FLATPAK_BUILDER_LINT=true
else
	acore_log_warning "org.flatpak.Builder is not installed via flatpak."
	acore_log_info "You can install it with: flatpak install flathub org.flatpak.Builder"
	acore_log_info "flatpak-builder-lint validations will be skipped."
	WARNINGS=$((WARNINGS + 1))
fi

# Define files to validate
METAINFO_FILE="$PROJECT_ROOT/src/linux/share/metainfo/me.ahmetcetinkaya.whph.metainfo.xml"
MANIFEST_FILE="$PROJECT_ROOT/packaging/flatpak/flathub/me.ahmetcetinkaya.whph.yaml"

# 1. Validate Desktop File
acore_log_section "Validating Desktop File"
# Search for built desktop file (since it's generated/copied during build)
DESKTOP_FILE=$(find "$PROJECT_ROOT/build-dir" "$PROJECT_ROOT/src/build" -name "me.ahmetcetinkaya.whph.desktop" 2>/dev/null | head -n 1)

if [ -n "$DESKTOP_FILE" ] && [ -f "$DESKTOP_FILE" ]; then
	acore_log_info "Found desktop file at: $DESKTOP_FILE"
	if command -v desktop-file-validate &>/dev/null; then
		if desktop-file-validate "$DESKTOP_FILE"; then
			acore_log_success "Desktop file validation passed."
		else
			acore_log_error "Desktop file validation failed."
			ERRORS=$((ERRORS + 1))
		fi
	else
		acore_log_warning "desktop-file-validate not found, skipping..."
	fi
else
	acore_log_warning "Desktop file not found in build directories."
	acore_log_info "Please run scripts/package_flatpak.sh to generate it."
	WARNINGS=$((WARNINGS + 1))
fi

# 2. Validate AppStream / MetaInfo
acore_log_section "Validating MetaInfo XML"
if [ -f "$METAINFO_FILE" ]; then
	if command -v appstreamcli &>/dev/null; then
		APPSTREAM_OUT=$(appstreamcli validate "$METAINFO_FILE" 2>&1)
		# appstreamcli returns non-zero on warnings too. Check if errors are present.
		if echo "$APPSTREAM_OUT" | grep -q "^E:"; then
			acore_log_error "MetaInfo validation via appstreamcli failed with errors."
			echo "$APPSTREAM_OUT" | grep "^E:"
			ERRORS=$((ERRORS + 1))
		else
			if echo "$APPSTREAM_OUT" | grep -q "^W:"; then
				acore_log_warning "MetaInfo validation via appstreamcli reported warnings:"
				echo "$APPSTREAM_OUT"
				WARNINGS=$((WARNINGS + 1))
			else
				acore_log_success "MetaInfo validation passed (appstreamcli)."
			fi
		fi
	else
		acore_log_warning "appstreamcli not found, skipping..."
	fi

	# Flatpak builder lint for AppStream
	if [ "$HAS_FLATPAK_BUILDER_LINT" = true ]; then
		LINT_APPSTREAM_OUT=$(flatpak run --command=flatpak-builder-lint org.flatpak.Builder appstream "$METAINFO_FILE" 2>&1)
		
		# Lint appstream returns 1 on warnings. To only fail on errors:
		if echo "$LINT_APPSTREAM_OUT" | grep -E -q "Validation failed:.*errors:"; then
			acore_log_error "MetaInfo validation via flatpak-builder-lint failed with errors."
			echo "$LINT_APPSTREAM_OUT" | awk '/\[ERROR\]/ || /^E:/ {print}'
			ERRORS=$((ERRORS + 1))
		else
			acore_log_success "MetaInfo validation passed without errors (flatpak-builder-lint)."
		fi
	fi
else
	acore_log_error "MetaInfo file not found at $METAINFO_FILE"
	ERRORS=$((ERRORS + 1))
fi

# 3. Validate Manifest
acore_log_section "Validating Flatpak Manifest"
if [ -f "$MANIFEST_FILE" ]; then
	if [ "$HAS_FLATPAK_BUILDER_LINT" = true ]; then
		acore_log_info "Running flatpak-builder-lint on manifest..."
		
		# We output to JSON to parse known exceptions documented in FLATPAK_PACKAGING.md
		LINT_MANIFEST_OUT=$(flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest "$MANIFEST_FILE" 2>&1)
		LINT_EXIT_CODE=$?
		
		if [ $LINT_EXIT_CODE -ne 0 ]; then
			acore_log_error "Manifest validation failed:"
			if command -v jq &>/dev/null && echo "$LINT_MANIFEST_OUT" | jq -e . &>/dev/null; then
				echo "$LINT_MANIFEST_OUT" | jq -r '.errors[]?' | while IFS= read -r err; do
					[ -n "$err" ] && acore_log_error "- $err"
				done
				echo "$LINT_MANIFEST_OUT" | jq -r '.info[]?' | while IFS= read -r info; do
					[ -n "$info" ] && acore_log_info "$info"
				done
				LINT_MSG=$(echo "$LINT_MANIFEST_OUT" | jq -r '.message // empty')
				if [ -n "$LINT_MSG" ]; then
					acore_log_info "$LINT_MSG"
				fi
			else
				echo "$LINT_MANIFEST_OUT"
			fi
			ERRORS=$((ERRORS + 1))
		else
			acore_log_success "Manifest validation passed."
		fi
	fi
else
	acore_log_warning "Generated manifest not found at $MANIFEST_FILE"
	acore_log_info "Run scripts/package_flatpak.sh first to generate the manifest."
	WARNINGS=$((WARNINGS + 1))
fi

# Summary
acore_log_section "Validation Summary"

if [ "$HAS_FLATPAK_BUILDER_LINT" = false ]; then
	acore_log_warning "Note: flatpak-builder-lint was skipped. Validation is incomplete."
fi

acore_log_info "Errors: $ERRORS"
acore_log_info "Warnings: $WARNINGS"

if [ $ERRORS -eq 0 ]; then
	acore_log_success "All flatpak validations passed! (Warnings are non-fatal)"
	exit 0
else
	acore_log_error "Flatpak validation failed with $ERRORS error(s). Please fix before publishing."
	exit 1
fi
