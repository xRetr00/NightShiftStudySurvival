#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

bash scripts/select_xcode.sh

xcodegen generate

xcodebuild test \
  -scheme NightShiftStudySurvival \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipPackagePluginValidation
