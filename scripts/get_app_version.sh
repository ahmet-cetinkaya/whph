#!/bin/bash

# Script to extract application version from pubspec.yaml
# This script is used across all CI workflows for consistency

set -e

# Extract version from pubspec.yaml (without build number)
APP_VERSION=$(awk '/^version:/ {print $2}' pubspec.yaml | cut -d'+' -f1)

# Validate that we got a version
if [ -z "$APP_VERSION" ]; then
    echo "ERROR: Could not extract version from pubspec.yaml"
    exit 1
fi

# Check if version follows semantic versioning pattern
if [[ ! $APP_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "WARNING: Version '$APP_VERSION' does not follow semantic versioning (x.y.z)"
fi

# Output the version
echo "APP_VERSION=$APP_VERSION"

# If running in GitHub Actions, set the environment variable
if [ -n "$GITHUB_ENV" ]; then
    echo "APP_VERSION=$APP_VERSION" >> $GITHUB_ENV
    echo "✅ Set APP_VERSION=$APP_VERSION in GitHub Actions environment"
else
    echo "ℹ️  APP_VERSION=$APP_VERSION (not in GitHub Actions environment)"
fi
