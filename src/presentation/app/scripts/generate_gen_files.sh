#!/usr/bin/env bash

echo "🧹 Cleaning build_runner cache..."
fvm flutter pub run build_runner clean

echo "🔨 Running generated files..."
fvm flutter pub run build_runner build --delete-conflicting-outputs

echo "🔨 Generating drift schema helper files for testing..."
fvm dart run drift_dev schema generate ../../infrastructure/persistence/shared/contexts/drift/schemas/app_database/ ../../../tests/unit_tests/infrastructure/persistence/shared/contexts/drift/app_database/generated

echo "✅ Code generation completed successfully!"
