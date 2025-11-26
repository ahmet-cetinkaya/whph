#!/usr/bin/env bash

echo "🔧 Fixing Dart code issues..."
cd src && fvm dart fix --apply

echo "📝 Formatting Dart files..."
cd src && fvm dart format . -l 120

echo "🎨 Formatting YAML, JSON, and Markdown files..."
prettier --write "src/**/*.{yaml,yml,json,md}" "!src/android/fdroid/**" "../**/*.md"

echo "🐚 Formatting shell scripts..."
shfmt -w -i 4 ./*.sh src/scripts/*.sh

echo "✅ Code formatting completed successfully!"