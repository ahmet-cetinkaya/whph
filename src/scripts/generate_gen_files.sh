#!/usr/bin/env bash

echo "🧹 Cleaning build_runner cache..."
fvm flutter pub run build_runner clean

echo "🔨 Running build_runner build..."
fvm flutter pub run build_runner build --delete-conflicting-outputs

echo "✅ Code generation completed successfully!"
