#!/usr/bin/env bash
set -e

trap 'echo "> ❌ Clean failed!"; exit 1' ERR

# Clean Flutter build artifacts
echo "> 🧹 Cleaning Flutter build..."
flutter clean

# Remove all contents of android/fdroid/build except extlib
echo "> 🗑️  Cleaning android/fdroid/build except extlib..."
if [ -d "android/fdroid/build" ]; then
  find android/fdroid/build -mindepth 1 -name extlib -prune -o -exec rm -rf {} +
fi

# Remove pub cache
echo "> 🗄️  Removing pub cache..."
rm -rf ~/.pub-cache/hosted/pub.dev/*

# Remove .dart_tool
echo "> 🗂️  Removing .dart_tool..."
rm -rf .dart_tool

# Repair and get pub packages
echo "> 🔧 Repairing and fetching pub packages..."
flutter pub cache repair
flutter pub get

echo "> ✅ Clean completed."
