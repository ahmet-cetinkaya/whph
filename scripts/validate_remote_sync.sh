#!/bin/bash

# Validation Script for Remote Sync Trigger

# 1. Ensure the app is running (you must launch it manually first)
echo "Please ensure WHPH is running separately."
echo "If not, start it with: fvm flutter run -d linux"
read -rp "Press Enter when app is running..."

# 2. Trigger Sync
echo "Triggering sync..."
# Requires building the bundle or using 'flutter run' with specific target, but strict CLI args
# usually work best with built binaries. If developing, we can try using dart run or similar if possible.
# But for 'flutter run', arguments are passed to the tool, not the app easily unless using --dart-entrypoint-args (not standard).
# Best way to test dev is likely to build a linux debug bundle or modify main() to print args.

# Assuming we can run from source using 'flutter run' and passing args to the app?
# No, flutter run args are for flutter.
# Effective test: Build the app.

cd src/
echo "Building Linux debug bundle (fast)..."
fvm flutter build linux --debug

echo "Running trigger..."
./build/linux/x64/debug/bundle/whph --sync

echo "Done. Check the logs of the MAIN app instance."
