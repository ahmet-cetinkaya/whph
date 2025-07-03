# WHPH Build Commands Reference

This document describes the available build commands for the WHPH Flutter application.

## Prerequisites

Install the RPS (Run Pub Scripts) package globally:
```bash
dart pub global activate rps
```

## Command Categories

### 🔒 Security Commands

- **`rps security-check`** - Run comprehensive security validation
  - Validates Gradle wrapper security
  - Checks dependency versions
  - Scans for sensitive files
  - Verifies build configuration

### 🏗️ Build Commands

#### Standard Builds
- **`rps build:apk`** - Build optimized release APK
  - Includes obfuscation and tree-shaking
  - Generates debug symbols
- **`rps build:bundle`** - Build Android App Bundle (AAB)
  - Optimized for Play Store distribution

#### Reproducible Builds
- **`rps build:apk:reproducible`** - Build reproducible APK
  - Full clean build with security validation
- **`rps build:bundle:reproducible`** - Build reproducible AAB
  - Full clean build with security validation

### 🚀 Release Commands

#### Android Release
- **`rps release:android`** - Build production APK with security validation
- **`rps release:android:bundle`** - Build production AAB with security validation
- **`rps release:android:reproducible`** - Build fully reproducible APK

#### Desktop Release
- **`rps release:linux`** - Build Linux executable
- **`rps release:windows`** - Build Windows executable
- **`rps release:windows:setup`** - Build Windows executable with installer

### 🛠️ Development Commands

- **`rps clean`** - Clean build artifacts
- **`rps format`** - Format code with 120-character line length
- **`rps gen`** - Generate code and format
- **`rps gen:icons`** - Generate app icons
- **`rps gen:migrate`** - Generate database migrations
- **`rps test`** - Run tests

### 📝 Documentation Commands

- **`rps gen:changelog`** - Generate changelog
- **`rps gen:changelog:all`** - Generate changelog for all versions

### 🔢 Version Management

- **`rps version:major`** - Bump major version (1.0.0 → 2.0.0)
- **`rps version:minor`** - Bump minor version (1.0.0 → 1.1.0)
- **`rps version:patch`** - Bump patch version (1.0.0 → 1.0.1)
- **`rps version:push`** - Push version tags and changes

### 🧪 Testing Commands

- **`rps test:ci`** - Run CI tests locally
- **`rps test:ci:android`** - Run Android CI tests
- **`rps test:ci:linux`** - Run Linux CI tests
- **`rps test:ci:windows`** - Run Windows CI tests
- **`rps test:ci:fdroid`** - Run F-Droid compatibility tests

### 🏃 Run Commands

- **`rps run:demo`** - Run app in demo mode

## Recommended Workflows

### For Development
```bash
rps security-check          # Validate security
rps build:apk               # Quick build for testing
```

### For Production Release
```bash
rps release:android:reproducible  # Full reproducible build
```

### For F-Droid/Open Source Distribution
```bash
rps build:apk:reproducible       # Reproducible build
rps test:ci:fdroid              # F-Droid compatibility test
```

### For Play Store Release
```bash
rps security-check              # Security validation
rps release:android:bundle      # AAB for Play Store
```

## Security Features

All release commands include:
- ✅ Security validation
- ✅ Code obfuscation
- ✅ Tree shaking
- ✅ Debug symbol extraction
- ✅ Minification
- ✅ Reproducible build support

## File Locations

- **APK Output**: `build/app/outputs/flutter-apk/app-release.apk`
- **AAB Output**: `build/app/outputs/bundle/release/app-release.aab`
- **Debug Symbols**: `build/app/outputs/symbols/`
- **Build Scripts**: `scripts/`

## Troubleshooting

### Security Validation Fails
```bash
# Check specific issues
rps security-check

# Fix common issues
flutter clean
flutter pub get
```

### Build Fails
```bash
# Clean everything
rps clean
flutter pub get
rps security-check
```

### Reproducible Build Issues
```bash
# Ensure clean environment
flutter clean
rm -rf build/
flutter pub get
rps build:apk:reproducible
```

## Manual Commands (without RPS)

If you prefer not to use RPS:

```bash
# Security check
bash scripts/security_validation.sh

# Build APK
flutter build apk --release --split-debug-info=build/app/outputs/symbols --obfuscate --tree-shake-icons

# Reproducible build
flutter clean && flutter pub get && bash scripts/security_validation.sh && flutter build apk --release --split-debug-info=build/app/outputs/symbols --obfuscate --tree-shake-icons
```
