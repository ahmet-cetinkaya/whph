# Windows CI Disabled - Visual Studio 2026 Compatibility Issue

**Status**: ✅ Re-enabled 2026-09-23 — pinned to the `windows-2022` runner
image **Originally disabled**: 2026-05-24 **Reason**: Flutter 3.32.0 cannot
detect Visual Studio 2026 on GitHub Actions `windows-latest` runner

---

## Problem

GitHub Actions `windows-latest` runner now redirects to `windows-2025-vs2026`
which includes:

- Visual Studio 2026 (version 18.x)
- No Visual Studio 2019 or 2022

Flutter 3.38.0's `vswhere` detection cannot find VS 2026, causing it to fall
back to "Visual Studio 16 2019" generator which doesn't exist on the runner.

**Error**:

```
CMake Error at CMakeLists.txt:3 (project):
  Generator: Visual Studio 16 2019
  could not find any instance of Visual Studio.
```

---

## Root Cause

**Flutter Issue**:
[flutter/flutter#176399](https://github.com/flutter/flutter/issues/176399)

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

## Resolution (2026-09-23)

Instead of waiting for Flutter's VS 2026 fix to reach our pinned SDK version,
`.github/workflows/flutter-ci.windows.yml` was pinned to `runs-on:
windows-2022` (a dedicated Windows Server 2022 + VS2022 image, distinct from
`windows-latest`). This sidesteps the VS 2026 detection bug entirely — no
Flutter SDK upgrade required. `windows-2022` is a maintained GitHub-hosted
image and is not scheduled for deprecation.

- Workflow trigger restored (`push: tags: v*.*.*`).
- `release.yml` re-includes `Flutter CI - Windows` in the required-workflows
  check, artifact download, zip/installer packaging, checksum comparison, and
  the published release asset list / notes.

Upstream, Flutter's own VS2026 detection was fixed in
[flutter/flutter#177458](https://github.com/flutter/flutter/pull/177458)
(merged 2025-11-01, targeted for 3.38.2+); if this project's Flutter pin is
ever upgraded past that version, `windows-latest` could be reconsidered, but
`windows-2022` remains the safer, lower-churn choice either way.

## Previous Workaround (superseded)

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

## Re-enable Checklist (completed 2026-09-23)

- [x] Pin `flutter-ci.windows.yml` to `runs-on: windows-2022`
- [x] Restore the `push: tags: v*.*.*` trigger
- [x] Re-include `Flutter CI - Windows` in `release.yml`'s required-workflow
      checks, artifact packaging, checksum comparison, and published assets
- [ ] Verify a real tag-triggered run on `windows-2022` produces a working
      installer + portable zip (pending first release after this change)

---

## Commits Related to This Issue

- `9afaa65b` fix(ci): use windows-2019 runner for Visual Studio 2019
  compatibility
- `bd7c4b31` fix(ci): correct Select-Object parameter name
- `e54fccd4` fix(ci): correct PowerShell syntax error in Flutter SDK check
- `96e32c4f` debug(ci): add checks for Flutter SDK hardcoded CMake generator
- `7a50c18f` fix(ci): use Visual Studio 18 2026 generator (matches
  windows-latest runner)
- `4ed56c2c` fix(ci): add intl dependency override for Flutter 3.38.0
  compatibility
- `77648301` fix(ci): force CMake generator to Visual Studio 17 2022
