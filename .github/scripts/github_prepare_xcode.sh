#!/bin/bash -eux

set -o pipefail

# Sometimes Xcode is 26.0, sometimes 26. We make sure it's usable no matter its name.
BASE_XCODE_PATH=/Applications/Xcode_26.0.app
TARGET_XCODE_PATH=/Applications/Xcode_26.app

if [ ! -e "$BASE_XCODE_PATH" ] && [ ! -e "$TARGET_XCODE_PATH" ]; then
  echo "Failed to find a suitable version of Xcode"
  exit 1
fi

if [ -e "$BASE_XCODE_PATH" ] && [ ! -e "$TARGET_XCODE_PATH" ]; then
  REAL_XCODE_PATH="$(readlink -f "$BASE_XCODE_PATH")"
  sudo mv "$REAL_XCODE_PATH" "$TARGET_XCODE_PATH"
fi

# Cleanup any other Xcode versions
sudo mv "$TARGET_XCODE_PATH" /Applications/tmp_Xcode_26.app
sudo rm -rf /Applications/Xcode*
sudo mv /Applications/tmp_Xcode_26.app "$TARGET_XCODE_PATH"

# Switch to target Xcode and clean simulators
sudo xcode-select --switch "$TARGET_XCODE_PATH"
sudo xcrun simctl delete all

# Make sure metal toolchain is installed
xcodebuild -downloadComponent MetalToolchain
