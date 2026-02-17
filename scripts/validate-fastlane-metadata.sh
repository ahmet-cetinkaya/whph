#!/bin/bash

# Fastlane Metadata Validation Script for F-Droid Compliance
# This script validates all language metadata directories for F-Droid requirements

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"
METADATA_DIR="$PROJECT_ROOT/fastlane/metadata/android"
ERRORS=0
WARNINGS=0

acore_log_header "Fastlane Metadata Validation for F-Droid Compliance"

# Function to check file exists and is not empty
check_file() {
    local file_path="$1"
    local file_type="$2"
    local lang="$3"

    if [ ! -f "$file_path" ]; then
        acore_log_error "ERROR: Missing $file_type for $lang"
        ERRORS=$((ERRORS + 1))
        return 1
    fi

    if [ ! -s "$file_path" ]; then
        acore_log_warning "WARNING: Empty $file_type for $lang"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi

    return 0
}

# Function to validate description length
validate_description_length() {
    local file_path="$1"
    local max_length="$2"
    local desc_type="$3"
    local lang="$4"

    if [ -f "$file_path" ]; then
        local length
        length=$(head -1 "$file_path" | tr -d '\n' | wc -m)
        if [ "$length" -gt "$max_length" ]; then
            acore_log_error "$desc_type too long for $lang ($length > $max_length chars)"
            ERRORS=$((ERRORS + 1))
        fi
    fi
}

# Function to validate changelog length
validate_changelog_length() {
    local file_path="$1"
    local lang="$2"
    local version="$3"

    if [ -f "$file_path" ]; then
        local byte_size
        byte_size=$(wc -c <"$file_path")
        if [ "$byte_size" -gt 500 ]; then
            acore_log_warning "Changelog $version.txt too long for $lang ($byte_size > 500 bytes)"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
}

# Check if metadata directory exists
if [ ! -d "$METADATA_DIR" ]; then
    acore_log_error "FATAL: Metadata directory not found: $METADATA_DIR"
    exit 1
fi

# Get all language directories (both xx and xx-XX formats)
# Exclude . and .. directories
LANGUAGES=$(find "$METADATA_DIR" -maxdepth 1 -type d ! -name "$METADATA_DIR" -exec basename {} \; | grep -E '^[a-z]{2}(-[A-Z]{2})?$' | sort)

if [ -z "$LANGUAGES" ]; then
    acore_log_error "FATAL: No language directories found in $METADATA_DIR"
    exit 1
fi

acore_log_info "Found $(echo "$LANGUAGES" | wc -l) language directories"

# Validate each language directory
for lang in $LANGUAGES; do
    lang_dir="$METADATA_DIR/$lang"

    # Skip incomplete directories (no title.txt means not a valid locale)
    if [ ! -f "$lang_dir/title.txt" ]; then
        acore_log_warning "Skipping $lang (no title.txt - incomplete locale)"
        continue
    fi

    acore_log_info "Validating $lang..."

    # Check required files
    check_file "$lang_dir/title.txt" "title.txt" "$lang"
    check_file "$lang_dir/short_description.txt" "short_description.txt" "$lang"
    check_file "$lang_dir/full_description.txt" "full_description.txt" "$lang"

    # Validate description lengths (F-Droid limits)
    validate_description_length "$lang_dir/title.txt" 50 "Title" "$lang"
    validate_description_length "$lang_dir/short_description.txt" 80 "Short description" "$lang"
    validate_description_length "$lang_dir/full_description.txt" 4000 "Full description" "$lang"

    # Check images directory
    if [ ! -d "$lang_dir/images" ]; then
        acore_log_warning "Missing images directory for $lang"
        WARNINGS=$((WARNINGS + 1))
    else
        # Check icon
        if [ ! -f "$lang_dir/images/icon.png" ]; then
            acore_log_warning "Missing icon.png for $lang"
            WARNINGS=$((WARNINGS + 1))
        fi

        # Check screenshots
        if [ ! -d "$lang_dir/images/phoneScreenshots" ]; then
            acore_log_warning "Missing phoneScreenshots directory for $lang"
            WARNINGS=$((WARNINGS + 1))
        else
            screenshot_count=$(find "$lang_dir/images/phoneScreenshots" -name "*.png" -type f 2>/dev/null | wc -l)
            if [ "$screenshot_count" -eq 0 ]; then
                acore_log_warning "No screenshots found for $lang"
                WARNINGS=$((WARNINGS + 1))
            elif [ "$screenshot_count" -lt 2 ]; then
                acore_log_warning "Only $screenshot_count screenshot(s) for $lang (minimum 2 recommended)"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    fi

    # Check changelogs
    if [ ! -d "$lang_dir/changelogs" ]; then
        acore_log_warning "Missing changelogs directory for $lang"
        WARNINGS=$((WARNINGS + 1))
    else
        changelog_count=$(find "$lang_dir/changelogs" -name "*.txt" -type f 2>/dev/null | wc -l)
        if [ "$changelog_count" -eq 0 ]; then
            acore_log_warning "No changelogs found for $lang"
            WARNINGS=$((WARNINGS + 1))
        else
            # Validate latest changelog exists
            latest_changelog=$(find "$lang_dir/changelogs" -name "*.txt" -type f 2>/dev/null | sort -V | tail -1)
            if [ -n "$latest_changelog" ]; then
                version=$(basename "$latest_changelog" .txt)
                validate_changelog_length "$latest_changelog" "$lang" "$version"
            fi
        fi
    fi

    acore_log_success "$lang validation complete"
done

# Summary
acore_log_section "Validation Summary"
acore_log_info "Languages validated: $(echo "$LANGUAGES" | wc -l)"
acore_log_info "Errors: $ERRORS"
acore_log_info "Warnings: $WARNINGS"

if [ $ERRORS -eq 0 ]; then
    acore_log_success "All validations passed! Metadata is F-Droid compliant."
    exit 0
else
    acore_log_error "Validation failed with $ERRORS error(s). Please fix before publishing."
    exit 1
fi
