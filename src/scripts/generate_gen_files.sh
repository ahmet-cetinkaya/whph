#!/usr/bin/env bash

echo "🧹 Cleaning build_runner cache..."
fvm flutter pub run build_runner clean

echo "🔨 Running build_runner build..."
fvm flutter pub run build_runner build --delete-conflicting-outputs

echo "🔧 Fixing relative imports to package imports for acore..."
find . -name "*.g.dart" -exec sed -i "s|import 'corePackages/acore/lib/|import 'package:acore/|g" {} \;

echo "✅ Code generation completed successfully!"
