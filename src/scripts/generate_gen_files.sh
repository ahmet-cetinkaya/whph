#!/usr/bin/env bash

echo "🧹 Cleaning build_runner cache..."
fvm flutter pub run build_runner clean

echo "🔨 Running generated files..."
fvm flutter pub run build_runner build --delete-conflicting-outputs

echo "🔨 Running generated drift migration files..."
fvm flutter pub run drift_dev make-migration

echo "✅ Code generation completed successfully!"
