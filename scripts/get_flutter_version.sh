#!/usr/bin/env bash

# Source acore logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"

# Navigate to src directory
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
cd "$SRC_DIR" || exit

# Read the pinned Flutter version from the exact SDK constraint in pubspec.yaml.
# Must resolve to a single checkout-able git ref (e.g. "3.32.0") so consumers
# like the F-Droid build can run `git reset --hard "$(get_flutter_version.sh)"`.
awk -F': ' '/^[[:space:]]*flutter:/ && !/sdk:/ {gsub(/"/,"",$2); print $2; exit}' pubspec.yaml
