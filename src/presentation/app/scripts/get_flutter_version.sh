#!/usr/bin/env bash
# Get the directory of the script and navigate to src directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(dirname "$SCRIPT_DIR")"
cd "$SRC_DIR" || exit

awk -F: '/^[[:space:]]*flutter:/ {gsub(/'\''|"/,"",$2); gsub(/^[[:space:]]+/,"",$2); print $2; exit}' pubspec.yaml
