#!/bin/bash
set -exo pipefail

sudo mdutil -a -i off
sudo xcode-select --switch /Applications/Xcode_16.4.app

brew install ninja coreutils python@3.13 quilt --overwrite
brew unlink python || true
brew link python@3.13 --force

pip3.13 install httplib2 requests Pillow --break

set +e
source dev.sh

set -e
he reset
he setup | tee setup.log

if [ "$1" = "sub" ]; then
  he sub
  exit 0
fi

set +e
if grep -q 'offset .* lines' setup.log; then
    grep -A20 -B20 'offset .* lines' setup.log >&2
    exit 1
fi

timeout 30 he build
_status_code=$?

if [ $_status_code != 124 ]; then
    echo "failed with status code $_status_code" >&2
    exit 1
fi
