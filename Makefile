SHELL := /bin/zsh
.ONESHELL:

# -------- Editable project vars --------
PROJECT      ?= LonelyPianist.xcodeproj
CONFIG       ?= Debug
DERIVED_DATA ?= .derivedData

# Supported: macos | ios | visionos
PLATFORM    ?= macos
DEVICE_OS   ?= latest
# -------------------------------------

ifeq ($(PLATFORM),ios)
SCHEME      ?= LonelyPianist
APP_NAME    ?= LonelyPianist
BUNDLE_ID   ?= com.chiimagnus.LonelyPianist
DEVICE_NAME ?= iPhone 15
DESTINATION ?= platform=iOS Simulator,name=$(DEVICE_NAME),OS=$(DEVICE_OS)
PRODUCT_DIR := $(CONFIG)-iphonesimulator
RUNTIME_FAMILY := iOS
else ifeq ($(PLATFORM),visionos)
SCHEME      ?= LonelyPianistAVP
APP_NAME    ?= LonelyPianistAVP
BUNDLE_ID   ?= com.chiimagnus.LonelyPianistAVP
DEVICE_NAME ?= Apple Vision Pro
DESTINATION ?= platform=visionOS Simulator,name=$(DEVICE_NAME),OS=$(DEVICE_OS)
PRODUCT_DIR := $(CONFIG)-xrsimulator
RUNTIME_FAMILY := xrOS
else ifeq ($(PLATFORM),macos)
SCHEME    ?= LonelyPianist
APP_NAME  ?= LonelyPianist
BUNDLE_ID ?= com.chiimagnus.LonelyPianist
DESTINATION ?= platform=macOS
PRODUCT_DIR := $(CONFIG)
else
$(error Unsupported PLATFORM '$(PLATFORM)'; use PLATFORM=macos, PLATFORM=ios, or PLATFORM=visionos)
endif

APP_PATH := $(DERIVED_DATA)/Build/Products/$(PRODUCT_DIR)/$(APP_NAME).app

XCODEBUILD := xcodebuild \
	-project "$(PROJECT)" \
	-scheme "$(SCHEME)" \
	-configuration "$(CONFIG)" \
	-derivedDataPath "$(DERIVED_DATA)" \
	-destination "$(DESTINATION)"

.PHONY: help build run run-macos run-ios run-visionos clean devices

help:
	@echo "Targets:"
	@echo "  make build                 # xcodebuild build"
	@echo "  make run                   # macOS: build+open; iOS/visionOS: build+install+launch simulator"
	@echo "  make clean                 # xcodebuild clean + remove derived data"
	@echo "  make devices               # list available simulators"
	@echo ""
	@echo "Common vars (override via VAR=...):"
	@echo "  PLATFORM=macos|ios|visionos  SCHEME=...  CONFIG=Debug|Release  DERIVED_DATA=.derivedData"
	@echo "  APP_NAME=...  BUNDLE_ID=..."
	@echo "  DEVICE_NAME=...  DEVICE_OS=latest|26.4"

build:
	@set -euo pipefail
	$(XCODEBUILD) build

run: run-$(PLATFORM)

run-macos: build
	@set -euo pipefail
	if [ ! -d "$(APP_PATH)" ]; then
		echo "App not found at: $(APP_PATH)"
		exit 1
	fi
	open "$(APP_PATH)"

run-ios: build
	@set -euo pipefail
	if [ ! -d "$(APP_PATH)" ]; then
		echo "App not found at: $(APP_PATH)"
		exit 1
	fi
	UDID="$$(DEVICE_NAME="$(DEVICE_NAME)" DEVICE_OS="$(DEVICE_OS)" RUNTIME_FAMILY="iOS" python3 - <<-'PY'
	import json
	import os
	import re
	import subprocess
	import sys

	device_name = os.environ.get("DEVICE_NAME", "").strip()
	device_os = os.environ.get("DEVICE_OS", "").strip()
	runtime_family = os.environ.get("RUNTIME_FAMILY", "").strip() or "iOS"

	data = json.loads(
	    subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
	)
	devices_by_runtime = data.get("devices", {})


	def runtime_version(runtime: str):
	    # Examples:
	    # - com.apple.CoreSimulator.SimRuntime.iOS-17-5
	    # - com.apple.CoreSimulator.SimRuntime.xrOS-2-2
	    m = re.search(
	        rf"\\.{re.escape(runtime_family)}-(\\d+)(?:-(\\d+))?(?:-(\\d+))?$", runtime
	    )
	    if not m:
	        return (-1, -1, -1)
	    major = int(m.group(1) or 0)
	    minor = int(m.group(2) or 0)
	    patch = int(m.group(3) or 0)
	    return (major, minor, patch)


	def runtime_matches_os(runtime: str) -> bool:
	    if not device_os or device_os.lower() == "latest":
	        return True
	    want = device_os.replace(".", "-")
	    return want in runtime


	runtimes = [rt for rt in devices_by_runtime.keys() if f".{runtime_family}-" in rt]
	if not runtimes:
	    print(
	        f"No {runtime_family} runtimes found. Install the Simulator runtime in Xcode.",
	        file=sys.stderr,
	    )
	    sys.exit(2)

	runtimes.sort(key=runtime_version, reverse=True)

	for rt in runtimes:
	    if not runtime_matches_os(rt):
	        continue
	    for d in devices_by_runtime.get(rt, []):
	        if d.get("name") == device_name:
	            print(d.get("udid", ""))
	            sys.exit(0)

	print(
	    f"No simulator matches DEVICE_NAME='{device_name}' DEVICE_OS='{device_os}'.",
	    file=sys.stderr,
	)
	sys.exit(1)
	PY
	)"
	echo "Using simulator UDID: $$UDID"
	open -a Simulator
	xcrun simctl boot "$$UDID" >/dev/null 2>&1 || true
	xcrun simctl bootstatus "$$UDID" -b
	xcrun simctl install "$$UDID" "$(APP_PATH)"
	xcrun simctl launch "$$UDID" "$(BUNDLE_ID)"

run-visionos: build
	@set -euo pipefail
	if [ ! -d "$(APP_PATH)" ]; then
		echo "App not found at: $(APP_PATH)"
		exit 1
	fi
	UDID="$$(DEVICE_NAME="$(DEVICE_NAME)" DEVICE_OS="$(DEVICE_OS)" RUNTIME_FAMILY="xrOS" python3 - <<-'PY'
	import json
	import os
	import re
	import subprocess
	import sys

	device_name = os.environ.get("DEVICE_NAME", "").strip()
	device_os = os.environ.get("DEVICE_OS", "").strip()
	runtime_family = os.environ.get("RUNTIME_FAMILY", "").strip() or "xrOS"

	data = json.loads(
	    subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
	)
	devices_by_runtime = data.get("devices", {})


	def runtime_version(runtime: str):
	    m = re.search(
	        rf"\\.{re.escape(runtime_family)}-(\\d+)(?:-(\\d+))?(?:-(\\d+))?$", runtime
	    )
	    if not m:
	        return (-1, -1, -1)
	    major = int(m.group(1) or 0)
	    minor = int(m.group(2) or 0)
	    patch = int(m.group(3) or 0)
	    return (major, minor, patch)


	def runtime_matches_os(runtime: str) -> bool:
	    if not device_os or device_os.lower() == "latest":
	        return True
	    want = device_os.replace(".", "-")
	    return want in runtime


	runtimes = [rt for rt in devices_by_runtime.keys() if f".{runtime_family}-" in rt]
	if not runtimes:
	    print(
	        f"No {runtime_family} runtimes found. Install the Simulator runtime in Xcode.",
	        file=sys.stderr,
	    )
	    sys.exit(2)

	runtimes.sort(key=runtime_version, reverse=True)

	for rt in runtimes:
	    if not runtime_matches_os(rt):
	        continue
	    for d in devices_by_runtime.get(rt, []):
	        if d.get("name") == device_name:
	            print(d.get("udid", ""))
	            sys.exit(0)

	print(
	    f"No simulator matches DEVICE_NAME='{device_name}' DEVICE_OS='{device_os}'.",
	    file=sys.stderr,
	)
	sys.exit(1)
	PY
	)"
	echo "Using simulator UDID: $$UDID"
	open -a Simulator
	xcrun simctl boot "$$UDID" >/dev/null 2>&1 || true
	xcrun simctl bootstatus "$$UDID" -b
	xcrun simctl install "$$UDID" "$(APP_PATH)"
	xcrun simctl launch "$$UDID" "$(BUNDLE_ID)"

clean:
	@set -euo pipefail
	$(XCODEBUILD) clean || true
	rm -rf "$(DERIVED_DATA)"

devices:
	@xcrun simctl list devices available
