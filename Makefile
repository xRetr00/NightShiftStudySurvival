SHELL := /bin/bash
.DEFAULT_GOAL := help

help:
	@echo "Targets:"
	@echo "  setup        - Install/check toolchain and generate Xcode project"
	@echo "  project      - Generate Xcode project"
	@echo "  build        - Build app on iOS Simulator"
	@echo "  test         - Run tests on iOS Simulator"
	@echo "  assets       - Regenerate local assets on Windows PowerShell"
	@echo "  web-sounds   - Download loud web alarm sounds"
	@echo "  import-preview JSON=... - Validate/import-preview backup JSON on Windows"

setup:
	bash scripts/macos_setup.sh

project:
	xcodegen generate

build:
	bash scripts/macos_build.sh

test:
	bash scripts/macos_test.sh

assets:
	pwsh -File scripts/generate_assets.ps1

web-sounds:
	bash scripts/macos_download_web_alarm_sounds.sh

import-preview:
	pwsh -File scripts/windows_import_preview.ps1 -JsonPath "$(JSON)"
