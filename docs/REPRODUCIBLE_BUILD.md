# Reproducible Build Guide for WHPH

This document describes how to achieve reproducible builds for the WHPH Flutter application.

## What are Reproducible Builds?

Reproducible builds are a set of software development practices that create a verifiable path from source code to binary. They enable verification that no vulnerabilities or backdoors have been introduced during the compilation process.

## Current Build Configuration

### Security Measures Implemented

1. **Gradle Wrapper Security**
   - Pinned to Gradle 8.4
   - Uses HTTPS distribution URL
   - Wrapper JAR integrity validation

2. **Dependency Management**
   - Flutter dependencies locked via `pubspec.lock`
   - Android dependencies pinned to specific versions
   - No dynamic version resolution (`+` versions avoided)

3. **Build Determinism**
   - Excluded non-deterministic files from packaging
   - Disabled build metadata that varies between builds
   - Configured deterministic packaging options

## Building Reproducible APKs

### Prerequisites

1. **Flutter SDK**: Version 3.32.0 (as specified in pubspec.yaml)
2. **Dart SDK**: Version ^3.5.3
3. **Java**: JDK 17
4. **Android SDK**: API level 35

### Build Steps

1. **Clean Environment**
   ```bash
   flutter clean
   rm -rf build/
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Validate Security**
   ```bash
   ./scripts/security_validation.sh
   ```

4. **Build Release APK**
   ```bash
   flutter build apk --release \
     --split-debug-info=build/app/outputs/symbols \
     --obfuscate \
     --tree-shake-icons
   ```

### Build Verification

After building, you can verify the build by:

1. **Checking File Hashes**
   ```bash
   sha256sum build/app/outputs/flutter-apk/app-release.apk
   ```

2. **Library Scanning**
   Use tools like LibScanner to verify no malicious libraries are included

3. **APK Analysis**
   ```bash
   aapt dump badging build/app/outputs/flutter-apk/app-release.apk
   ```

## Build Environment

### Recommended Environment Variables

```bash
export FLUTTER_ROOT=/path/to/flutter
export ANDROID_HOME=/path/to/android-sdk
export JAVA_HOME=/path/to/java17
export PATH=$FLUTTER_ROOT/bin:$ANDROID_HOME/platform-tools:$PATH
```

### Docker Build (Optional)

For maximum reproducibility, consider using a Docker container:

```dockerfile
FROM cirrusci/flutter:3.32.0

WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build apk --release --split-debug-info=symbols
```

## Verification Steps

1. **Source Code Verification**
   - Verify git commit hash matches expected version
   - Check no uncommitted changes exist

2. **Dependency Verification**
   - Ensure `pubspec.lock` is committed and up-to-date
   - Verify all Android dependencies are pinned

3. **Build Output Verification**
   - Compare APK hashes across different build environments
   - Verify APK contents match expected structure

## Security Considerations

### Supply Chain Security

1. **Gradle Wrapper**
   - Always use HTTPS for distribution URLs
   - Verify wrapper JAR checksums
   - Pin Gradle version explicitly

2. **Dependencies**
   - Avoid dynamic version resolution
   - Regularly audit dependencies for vulnerabilities
   - Use dependency scanning tools

3. **Build Environment**
   - Use clean build environments
   - Avoid caching between builds when reproducibility is critical
   - Document exact tool versions used

### Code Signing

The application uses release signing configuration from `android/key.properties`:
- Key store file: `whph-release.keystore`
- Signing ensures APK integrity and authenticity

## F-Droid Compatibility

This build configuration is designed to be compatible with F-Droid's reproducible build requirements:

1. **No proprietary dependencies**
2. **Deterministic build process**
3. **Source code availability**
4. **Build documentation provided**

## Troubleshooting

### Common Issues

1. **Build Not Reproducible**
   - Check for timestamp dependencies
   - Verify all versions are pinned
   - Remove build metadata

2. **Gradle Issues**
   - Clear Gradle cache: `./gradlew clean`
   - Regenerate wrapper: `gradle wrapper`

3. **Flutter Issues**
   - Clear Flutter cache: `flutter clean`
   - Regenerate pub cache: `flutter pub cache repair`

## References

- [Reproducible Builds Project](https://reproducible-builds.org/)
- [Flutter Build Documentation](https://flutter.dev/docs/deployment/android)
- [Gradle Build Security](https://blog.gradle.org/project-integrity)
- [F-Droid Reproducible Builds](https://f-droid.org/en/docs/Reproducible_Builds/)

## Verification Command Summary

```bash
# Quick security validation
./scripts/security_validation.sh

# Full reproducible build
flutter clean && \
flutter pub get && \
flutter build apk --release --split-debug-info=symbols --obfuscate

# Verify build output
sha256sum build/app/outputs/flutter-apk/app-release.apk
```
