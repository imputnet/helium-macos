#!/bin/bash
set -ex

pip3 install requests --break-system-packages
export PATH="$PWD/build/src/out/Default:$PATH"

python3 ./devutils/generate_sparkle_deltas.py "$@"

echo 'deltas<<EOF' >> "$GITHUB_OUTPUT"
find ./release_asset/ -name '*.delta' >> "$GITHUB_OUTPUT"
echo EOF >> "$GITHUB_OUTPUT"
