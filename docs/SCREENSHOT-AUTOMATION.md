# Fastlane Configuration for WHPH

This directory contains Fastlane configuration for automated app store deployments and screenshot capture.

## Structure

- `Appfile` - App bundle identifier configuration
- `Fastfile` - Lane definitions for deployment and screenshots
- `Screengrabfile` - Android screenshot configuration
- `Snapfile` - iOS screenshot configuration
- `fastlane/screenshot_config.yaml` - Cross-platform screenshot settings
- `fastlane/metadata/android/` - Google Play Store metadata by locale
- `fastlane/metadata/ios/` - iOS metadata (if applicable)

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

# Android only (Using the script)
# Generate for all locales (default)
rps gen:screenshots
# Or directly: cd src && bash scripts/generate_screenshots.sh --all

# Generate for a specific locale
rps gen:screenshots tr
# Or directly: cd src && bash scripts/generate_screenshots.sh tr

# iOS only (requires macOS)
fastlane ios ios_screenshots

# Validate screenshots
fastlane validate_screenshots
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
   - Defined in `fastlane/screenshot_config.yaml`

4. **Output**:
   - Android: `fastlane/metadata/android/{locale}/images/phoneScreenshots/`
   - iOS: `fastlane/metadata/ios/{locale}/`

## Running Screenshots

```bash
# 1. Start Android emulator
emulator -avd Pixel_8 &

# 2. Navigate to project root
cd /path/to/whph

# 3. Run screenshot capture (e.g., for all locales)
rps gen:screenshots

# 4. Validate results
fastlane validate_screenshots
```

## Configuration

### screenshot_config.yaml

Defines:

- Locale mappings (Flutter → Android → iOS)
- Screenshot scenarios (8 screens)
- Device configurations
- Retry settings

### Integration Tests

Located in `src/test/integration/screenshot_grabbing/`:

- `screenshot_config.dart` - Dart configuration
- `screenshot_capture.dart` - Main test file
- `test_driver.dart` - Integration test driver (extended for screenshots)

## Metadata Structure

```text
fastlane/metadata/android/
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
│           ├── 2.png  (Task details)
│           ├── 3.png  (Habit details)
│           ├── 4.png  (Habit statistics)
│           ├── 5.png  (Note details)
│           ├── 6.png  (App usage overview)
│           ├── 7.png  (App usage statistics)
│           └── 8.png  (Tags)
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
- **Screenshot Driver**: `src/test/integration/screenshot_grabbing/test_driver.dart`
- **Screenshot Test**: `src/test/integration/screenshot_grabbing/screenshot_capture.dart`
- **Configuration**: `fastlane/screenshot_config.yaml`
```

### Locale not changing

- Device locale is set via ADB but may require restart
- App locale is controlled by `SCREENSHOT_LOCALE` env var
