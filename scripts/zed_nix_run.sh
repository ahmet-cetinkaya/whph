#!/usr/bin/env bash
# Wrapper used by Zed run tasks to execute a command inside the Nix dev shell,
# so the Linux desktop build gets the native tooling it needs (ninja, CMake,
# GTK/X11/Wayland libs). Without this, `fvm flutter run` fails on NixOS with
# "CMake Error ... ninja ... No such file or directory".
#
# Usage: zed_nix_run.sh <subdir> <command...>
#   <subdir>     directory (relative to repo root) to run the command in,
#                e.g. "src" for the Flutter project, "." for the repo root.
#   <command...> the command and args to run inside the dev shell.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SUBDIR="${1:?usage: zed_nix_run.sh <subdir> <command...>}"
shift

# Enter the flake dev shell (finds flake.nix via REPO_ROOT), cd into the target
# subdirectory, then exec the requested command with its arguments intact.
# shellcheck disable=SC2016 # The inner Bash must expand these positional parameters.
exec nix develop "$REPO_ROOT" --command bash -c '
  cd "$1/$2" || exit 1
  shift 2
  exec "$@"
' bash "$REPO_ROOT" "$SUBDIR" "$@"
