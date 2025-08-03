#!/bin/bash

# Fastlane Metadata Validation Script for F-Droid Compliance
# This script validates all language metadata directories for F-Droid requirements

set -e

METADATA_DIR="/home/ac/Code/ahmet-cetinkaya/whph/fastlane/metadata/android"
ERRORS=0
WARNINGS=0

echo "🔍 Fastlane Metadata Validation for F-Droid Compliance"
echo "======================================================="
echo

# Function to check file exists and is not empty
check_file() {
    local file_path="$1"
    local file_type="$2"
    local lang="$3"
    
    if [ ! -f "$file_path" ]; then
        echo "❌ ERROR: Missing $file_type for $lang"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
    
    if [ ! -s "$file_path" ]; then
        echo "⚠️  WARNING: Empty $file_type for $lang"
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
        local length=$(head -1 "$file_path" | wc -c)
        if [ $length -gt $max_length ]; then
            echo "❌ ERROR: $desc_type too long for $lang ($length > $max_length chars)"
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
        local byte_size=$(wc -c < "$file_path")
        if [ $byte_size -gt 500 ]; then
            echo "⚠️  WARNING: Changelog $version.txt too long for $lang ($byte_size > 500 bytes)"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
}

# Check if metadata directory exists
if [ ! -d "$METADATA_DIR" ]; then
    echo "❌ FATAL: Metadata directory not found: $METADATA_DIR"
    exit 1
fi

# Get all language directories
LANGUAGES=$(find "$METADATA_DIR" -maxdepth 1 -type d -name "*-*" -exec basename {} \; | sort)

if [ -z "$LANGUAGES" ]; then
    echo "❌ FATAL: No language directories found in $METADATA_DIR"
    exit 1
fi

echo "📁 Found $(echo "$LANGUAGES" | wc -l) language directories"
echo

# Validate each language directory
for lang in $LANGUAGES; do
    echo "🌍 Validating $lang..."
    lang_dir="$METADATA_DIR/$lang"
    
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
        echo "⚠️  WARNING: Missing images directory for $lang"
        WARNINGS=$((WARNINGS + 1))
    else
        # Check icon
        if [ ! -f "$lang_dir/images/icon.png" ]; then
            echo "⚠️  WARNING: Missing icon.png for $lang"
            WARNINGS=$((WARNINGS + 1))
        fi
        
        # Check screenshots
        if [ ! -d "$lang_dir/images/phoneScreenshots" ]; then
            echo "⚠️  WARNING: Missing phoneScreenshots directory for $lang"
            WARNINGS=$((WARNINGS + 1))
        else
            screenshot_count=$(ls "$lang_dir/images/phoneScreenshots"/*.png 2>/dev/null | wc -l)
            if [ $screenshot_count -eq 0 ]; then
                echo "⚠️  WARNING: No screenshots found for $lang"
                WARNINGS=$((WARNINGS + 1))
            elif [ $screenshot_count -lt 2 ]; then
                echo "⚠️  WARNING: Only $screenshot_count screenshot(s) for $lang (minimum 2 recommended)"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    fi
    
    # Check changelogs
    if [ ! -d "$lang_dir/changelogs" ]; then
        echo "⚠️  WARNING: Missing changelogs directory for $lang"
        WARNINGS=$((WARNINGS + 1))
    else
        changelog_count=$(ls "$lang_dir/changelogs"/*.txt 2>/dev/null | wc -l)
        if [ $changelog_count -eq 0 ]; then
            echo "⚠️  WARNING: No changelogs found for $lang"
            WARNINGS=$((WARNINGS + 1))
        else
            # Validate latest changelog exists
            latest_changelog=$(ls "$lang_dir/changelogs"/*.txt 2>/dev/null | sort -V | tail -1)
            if [ -n "$latest_changelog" ]; then
                version=$(basename "$latest_changelog" .txt)
                validate_changelog_length "$latest_changelog" "$lang" "$version"
            fi
        fi
    fi
    
    echo "   ✅ $lang validation complete"
    echo
done

# Summary
echo "📊 Validation Summary"
echo "===================="
echo "Languages validated: $(echo "$LANGUAGES" | wc -l)"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo

if [ $ERRORS -eq 0 ]; then
    echo "🎉 All validations passed! Metadata is F-Droid compliant."
    exit 0
else
    echo "💥 Validation failed with $ERRORS error(s). Please fix before publishing."
    exit 1
fi