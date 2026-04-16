#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$REPO_ROOT/NightShiftStudySurvival/Resources/Sounds"
mkdir -p "$TARGET_DIR"

curl -L "https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3" -o "$TARGET_DIR/web_disaster.mp3"
curl -L "https://assets.mixkit.co/active_storage/sfx/2935/2935-preview.mp3" -o "$TARGET_DIR/web_nuclear.mp3"
curl -L "https://assets.mixkit.co/active_storage/sfx/2899/2899-preview.mp3" -o "$TARGET_DIR/web_red_alert.mp3"

echo "Web alarm sounds downloaded into $TARGET_DIR"
