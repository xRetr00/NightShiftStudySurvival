#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode from App Store and open it once." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen with Homebrew..."
  brew install xcodegen
fi

bash scripts/select_xcode.sh
xcodebuild -version

echo "Generating Xcode project..."
xcodegen generate

echo "Setup complete. Open NightShiftStudySurvival.xcodeproj in Xcode."
