#!/usr/bin/env bash
set -e

trap 'echo "> ❌ F-Droid CI failed!"; exit 1' ERR

# F-Droid CI test script for whph
# Usage: bash scripts/test_ci_fdroid.sh

cd src/android/fdroid

echo "> ⚙️ Setting up F-Droid environment..."
python -m venv .fdroid-venv
source .fdroid-venv/bin/activate
pip install --upgrade pip
pip install fdroidserver androguard
echo "> ✅ F-Droid environment setup complete"

# Read metadata to check for syntax errors
echo "> 🔍 Checking metadata syntax..."
fdroid readmeta
echo "> ✅ fdroid readmeta passed"

# Clean up metadata file
echo "> 🧹 Cleaning up metadata..."
fdroid rewritemeta me.ahmetcetinkaya.whph
echo "> ✅ fdroid rewritemeta passed"

# Fill automated fields like Auto Name and Current Version
echo "> 🔧 Filling automated fields..."
fdroid checkupdates me.ahmetcetinkaya.whph
echo "> ✅ fdroid checkupdates passed"

# Lint check for warnings
echo "> 🔍 Running F-Droid lint..."
fdroid lint me.ahmetcetinkaya.whph
echo "> ✅ fdroid lint passed"

# Test build recipe with verbose and logging
echo "> 🔨 Building F-Droid repository..."
fdroid build -v -l me.ahmetcetinkaya.whph
echo "> ✅ fdroid build passed"
