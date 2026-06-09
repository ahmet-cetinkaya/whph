# Flutter Version Management

## Pinning

Flutter SDK is pinned to an **exact version** in two places:

| File               | Field                 | Example    |
| ------------------ | --------------------- | ---------- |
| `src/.fvmrc`       | `flutter`             | `"3.32.0"` |
| `src/pubspec.yaml` | `environment.flutter` | `"3.32.0"` |

Both must match. The `.fvmrc` controls `fvm flutter` locally; `pubspec.yaml`
controls the SDK constraint resolved by `pub get`.

## Script

`scripts/get_flutter_version.sh` emits the pinned version as a single
checkout-able git ref. Used by the F-Droid build to reset Flutter SDK to the
pinned version.

The script parses the exact version from `pubspec.yaml`. It must output exactly
one line — a tag like `3.32.0` — with no extra output.

## Constraints

- **Do not** use a version range (`>=3.24.0 <3.38.0`) in `pubspec.yaml` — the
  F-Droid build consumes the version via `git reset --hard` and ranges are not
  valid git refs.
- **Do not** rely on `.fvmrc` alone — the F-Droid build environment does not use
  FVM; it reads the version from the script.
