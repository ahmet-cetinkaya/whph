#!/usr/bin/env bash

# Source acore logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

# Navigate to src directory
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
cd "$SRC_DIR" || exit

awk -F: '/^[[:space:]]*flutter:/ {gsub(/'\''|"/,"",$2); gsub(/^[[:space:]]+/,"",$2); print $2; exit}' pubspec.yaml
