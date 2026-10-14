#!/bin/bash -eux

# Simple script for setting up all toolchain dependencies for building Helium on macOS

brew install coreutils zstd --overwrite

if ! command -v sccache 2>&1 >/dev/null; then
  brew install sccache --overwrite
fi

# Install Python dependencies from PyPI
pip3 install requests pillow --break-system-packages
