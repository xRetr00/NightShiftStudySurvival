#!/usr/bin/env bash
set -euo pipefail

choose_latest_xcode() {
  local latest26
  latest26="$(ls -d /Applications/Xcode_26*.app 2>/dev/null | sort -V | tail -n 1 || true)"
  if [[ -n "${latest26}" ]]; then
    echo "${latest26}"
    return 0
  fi

  local latest16
  latest16="$(ls -d /Applications/Xcode_16*.app 2>/dev/null | sort -V | tail -n 1 || true)"
  if [[ -n "${latest16}" ]]; then
    echo "${latest16}"
    return 0
  fi

  if [[ -d "/Applications/Xcode.app" ]]; then
    echo "/Applications/Xcode.app"
    return 0
  fi

  return 1
}

XCODE_APP_PATH="$(choose_latest_xcode)" || {
  echo "Could not locate an installed Xcode application under /Applications." >&2
  exit 1
}

DEVELOPER_DIR_PATH="${XCODE_APP_PATH}/Contents/Developer"

if [[ "${1:-}" == "--path-only" ]]; then
  echo "${DEVELOPER_DIR_PATH}"
  exit 0
fi

export DEVELOPER_DIR="${DEVELOPER_DIR_PATH}"
echo "Selected Xcode: ${XCODE_APP_PATH}"
echo "DEVELOPER_DIR=${DEVELOPER_DIR}"
