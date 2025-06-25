#!/usr/bin/env bash
set -e

# F-Droid CI test script for whph
# Usage: bash scripts/test_ci_fdroid.sh

cd android/fdroid

python -m venv .fdroid-venv
source .fdroid-venv/bin/activate
pip install --upgrade pip
pip install fdroidserver androguard
echo "✅ python env activated"

fdroid lint me.ahmetcetinkaya.whph
echo "✅ fdroid lint passed"

fdroid build me.ahmetcetinkaya.whph
echo "✅ fdroid build passed"
