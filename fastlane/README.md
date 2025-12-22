# Fastlane Configuration for WHPH

This directory contains Fastlane configuration for automated app store deployments and screenshot capture.

## Structure

- `Appfile` - App bundle identifier configuration
- `Fastfile` - Lane definitions for deployment and screenshots
- `Screengrabfile` - Android screenshot configuration
- `Snapfile` - iOS screenshot configuration
- `screenshot_config.yaml` - Cross-platform screenshot settings
- `metadata/android/` - Google Play Store metadata by locale

## Available Lanes

### Deployment (Android)

```bash
# Internal testing
fastlane android deploy_internal

# Alpha/Beta/Production
fastlane android deploy_alpha
fastlane android deploy_beta
fastlane android deploy_production

# Metadata only
fastlane android update_metadata
```

### Screenshots

```bash
# Capture all screenshots (Android + iOS)
fastlane screenshots

# Android only
fastlane android screenshots_android

# Specific locales
fastlane android screenshots_android locales:en-US,de-DE,tr-TR

# iOS only (requires macOS)
fastlane ios screenshots_ios

# Validate screenshots
fastlane validate_screenshots

# Organize for store upload
fastlane organize_screenshots
```

## Screenshot Automation

The screenshot system uses Flutter integration tests to capture screenshots:

1. **Prerequisites**:
   - Android: Running emulator (`emulator -avd Pixel_8`)
   - iOS: macOS with Xcode and iOS Simulator

2. **Demo Mode**:
   - Screenshots are captured with `DEMO_MODE=true`
   - App displays consistent demo data

3. **Locales**:
   - 22 locales supported
   - Defined in `screenshot_config.yaml`

4. **Output**:
   - Android: `metadata/android/{locale}/images/phoneScreenshots/`
   - iOS: `metadata/ios/{locale}/`

## Running Screenshots

```bash
# 1. Start Android emulator
emulator -avd Pixel_8 &

# 2. Navigate to project root
cd /path/to/whph

# 3. Run screenshot capture
fastlane android screenshots_android

# 4. Validate results
fastlane validate_screenshots
```

## Configuration

### screenshot_config.yaml

Defines:
- Locale mappings (Flutter → Android → iOS)
- Screenshot scenarios (10 screens)
- Device configurations
- Retry settings

### Integration Tests

Located in `src/integration_test/`:
- `screenshot_config.dart` - Dart configuration
- `screenshot_test.dart` - Main test file

## Metadata Structure

```
metadata/android/
├── en-US/
│   ├── title.txt
│   ├── short_description.txt
│   ├── full_description.txt
│   ├── changelogs/
│   │   └── {versionCode}.txt
│   └── images/
│       ├── icon.png
│       └── phoneScreenshots/
│           ├── 1.png  (Today page)
│           ├── 2.png  (Task list)
│           ├── 3.png  (Task details)
│           ├── 4.png  (Habits)
│           ├── 5.png  (Calendar)
│           ├── 6.png  (Notes)
│           ├── 7.png  (Statistics)
│           ├── 8.png  (Tags)
│           ├── 9.png  (Settings)
│           └── 10.png (Sync)
├── de-DE/
├── tr-TR/
└── ... (22 locales total)
```

## Troubleshooting

### No device found
```bash
# Check connected devices
adb devices

# Start emulator
emulator -avd Pixel_8

# Or use physical device with USB debugging
```

### Flutter drive fails
```bash
# Ensure Flutter is correct version
fvm flutter --version

# Get dependencies
cd src && fvm flutter pub get

# Try running test directly
fvm flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  --dart-define=DEMO_MODE=true
```

### Locale not changing
- Device locale is set via ADB but may require restart
- App locale is controlled by `SCREENSHOT_LOCALE` env var
