#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

export DEVELOPER_DIR="$(bash scripts/select_xcode.sh --path-only)"
echo "Using DEVELOPER_DIR=$DEVELOPER_DIR"

xcodegen generate

xcodebuild test \
  -scheme NightShiftStudySurvival \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipPackagePluginValidation
