#!/bin/bash
set -exo pipefail

sudo mdutil -a -i off

brew install ninja coreutils python@3.14 quilt llvm@20 --overwrite
brew unlink python || true
brew link python@3.14 llvm@20 --force

pip3.14 install httplib2==0.22.0 requests Pillow --break

source dev.sh

export QUILT_PATCHES="$PWD/patches"
export QUILT_SERIES="series.merged"

he reset
he setup | tee setup.log

if [ "$1" = "sub" ]; then
    he sub

    cd "$_src_dir"
    cat components/omnibox_strings.grdp | grep -q Helium
    exit 0
fi

set +e
if grep -q 'offset .* lines' setup.log; then
    grep -A20 -B20 'offset .* lines' setup.log >&2
    exit 1
fi

cd "$_src_dir"
timeout 30 ninja -C out/Default chrome chromedriver
_status_code=$?

if [ $_status_code != 124 ]; then
    echo "failed with status code $_status_code" >&2
    exit 1
fi
