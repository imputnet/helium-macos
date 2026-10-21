#!/bin/bash -eux

BASE_XCODE_PATH=/Applications/Xcode_26.5.app
TARGET_XCODE_PATH=/Applications/Xcode_26.app

REAL_XCODE_PATH="$(readlink -f "$BASE_XCODE_PATH")"

# Cleanup any other Xcode versions
sudo mv "$REAL_XCODE_PATH" /Applications/tmp_Xcode_26.app
sudo rm -rf /Applications/Xcode*
sudo mv /Applications/tmp_Xcode_26.app "$TARGET_XCODE_PATH"

# Switch to target Xcode and clean simulators
sudo xcode-select --switch "$TARGET_XCODE_PATH"
sudo xcrun simctl delete all

# Make sure metal toolchain is installed
xcodebuild -downloadComponent MetalToolchain
