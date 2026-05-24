# Windows CI Disabled - Visual Studio 2026 Compatibility Issue

**Status**: ⚠️ Windows CI temporarily disabled
**Date**: 2026-05-24
**Reason**: Flutter 3.38.0 cannot detect Visual Studio 2026 on GitHub Actions `windows-latest` runner

---

## Problem

GitHub Actions `windows-latest` runner now redirects to `windows-2025-vs2026` which includes:
- Visual Studio 2026 (version 18.x)
- No Visual Studio 2019 or 2022

Flutter 3.38.0's `vswhere` detection cannot find VS 2026, causing it to fall back to "Visual Studio 16 2019" generator which doesn't exist on the runner.

**Error**:
```
CMake Error at CMakeLists.txt:3 (project):
  Generator: Visual Studio 16 2019
  could not find any instance of Visual Studio.
```

---

## Root Cause

**Flutter Issue**: [flutter/flutter#176399](https://github.com/flutter/flutter/issues/176399)
- Flutter's `visual_studio.dart` maps VS versions to CMake generators
- VS 18 (2026) mapping exists but detection fails
- Flutter ignores `CMAKE_GENERATOR` environment variable

**GitHub Actions Notice**:
- `windows-latest` redirects to `windows-2025-vs2026` by June 15, 2026
- Free tier doesn't have access to `windows-2019` runner

---

## Workarounds Considered

1. **Use `windows-2019` runner**: Not available on GitHub Free tier
2. **Install VS 2022 build tools**: Adds 5-10 min to build time
3. **Modify CMakeLists.txt**: Breaks on `flutter pub get`
4. **Wait for Flutter fix**: Unknown timeline

---

## Current Solution

**Manual builds** until Flutter adds proper VS 2026 support.

### Build Process (Windows)

```bash
# From project root
cd src
fvm flutter build windows --release

# Create installer (requires Inno Setup)
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" ..\packaging\inno-setup\installer.iss

# Upload to GitHub Releases
gh release create <version> \
  build/windows/x64/runner/Release/whph.exe \
  build/windows/x64/runner/Release/*.dll \
  build/windows/installer/whph-setup.exe
```

---

## References

- [Flutter Issue #176399: Add Support for VisualStudio 2026](https://github.com/flutter/flutter/issues/176399)
- [GitHub Actions: windows-latest deprecation notice](https://github.com/actions/runner-images/issues/11384)
- [CMake Generators documentation](https://cmake.org/cmake/help/latest/manual/cmake-generators.7.html)

---

## Re-enable Checklist

- [ ] Flutter releases version with VS 2026 support
- [ ] Test on `windows-latest` runner
- [ ] Remove workflow disable (rename file)
- [ ] Verify build and installer creation

---

## Commits Related to This Issue

- `9afaa65b` fix(ci): use windows-2019 runner for Visual Studio 2019 compatibility
- `bd7c4b31` fix(ci): correct Select-Object parameter name  
- `e54fccd4` fix(ci): correct PowerShell syntax error in Flutter SDK check
- `96e32c4f` debug(ci): add checks for Flutter SDK hardcoded CMake generator
- `7a50c18f` fix(ci): use Visual Studio 18 2026 generator (matches windows-latest runner)
- `4ed56c2c` fix(ci): add intl dependency override for Flutter 3.38.0 compatibility
- `77648301` fix(ci): force CMake generator to Visual Studio 17 2022
