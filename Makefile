SHELL := /bin/bash
.DEFAULT_GOAL := help

help:
	@echo "Targets:"
	@echo "  setup        - Install/check toolchain and generate Xcode project"
	@echo "  project      - Generate Xcode project"
	@echo "  build        - Build app on iOS Simulator"
	@echo "  test         - Run tests on iOS Simulator"
	@echo "  assets       - Regenerate local assets on Windows PowerShell"

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
