#!/usr/bin/env bash
# Wrapper used by Zed's Dart debug adapter (customTool) to launch Flutter
# inside the Nix dev shell, so the debug/run session has the same SDK and
# native runtime dependencies (X11/Wayland, CMake libs) that `nix develop`
# provides. Zed passes the full `flutter <args...>` invocation as arguments
# (typically `flutter debug_adapter ...`).
#
# Device selection (avoiding "More than one device connected" when both the
# Linux desktop and Chrome are attached) is NOT done here: the debug adapter
# launches the actual `flutter run` itself over DAP, not via the argv this
# script receives, so a `-d` flag injected into this argv never reaches it.
# Set the target device via the launch config's `deviceId` field instead
# (see .zed/debug.json).
set -euo pipefail

# Resolve the repo root (this script lives in <root>/scripts/).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Run inside the flake dev shell (puts fvm's pinned Flutter SDK on PATH).
exec nix develop "$REPO_ROOT" --command "$@"
