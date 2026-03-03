#!/usr/bin/env bash

# Script to retrieve and unpack resources to build Chromium macOS

set -eux

_root_dir="$(dirname "$(greadlink -f "$0")")"
_download_cache="$_root_dir/build/download_cache"
_src_dir="$_root_dir/build/src"
_main_repo="$_root_dir/helium-chromium"

# Clone to get the Chromium Source
clone=true
retrieve_generic=false
retrieve_toolchain=false

while getopts 'dgt' OPTION; do
  case "$OPTION" in
    d)
        clone=false
        ;;
    g)
        retrieve_generic=true
        ;;
    t)
        retrieve_toolchain=true
        ;;
    ?)
        echo "Usage: $0 [-d] [-g] [-p]"
        echo "  -d: Use download instead of git clone to get Chromium Source"
        echo "  -g: Retrieve and unpack Chromium Source and general resources"
        echo "  -t: Retrieve and unpack Chromium toolchain"
        exit 1
        ;;
    esac
done

shift "$(($OPTIND -1))"

_target_cpu=${1:-arm64}

if $retrieve_generic; then
    if $clone; then
        if [[ $_target_cpu == "arm64" ]]; then
            # For arm64 (Apple Silicon)
            python3 "$_main_repo/utils/clone.py" -p mac-arm -o "$_src_dir"
        else
            # For amd64 (Intel)
            python3 "$_main_repo/utils/clone.py" -p mac -o "$_src_dir"
        fi
    else
        python3 "$_main_repo/utils/downloads.py" retrieve -i "$_main_repo/downloads.ini" -c "$_download_cache"
        python3 "$_main_repo/utils/downloads.py" unpack -i "$_main_repo/downloads.ini" -c "$_download_cache" "$_src_dir"
    fi

    # Retrieve and unpack general resources
    python3 "$_main_repo/utils/downloads.py" retrieve -i "$_root_dir/downloads.ini" -c "$_download_cache"
    python3 "$_main_repo/utils/downloads.py" retrieve -i "$_main_repo/deps.ini" -c "$_download_cache"
    python3 "$_main_repo/utils/downloads.py" unpack -i "$_root_dir/downloads.ini" -c "$_download_cache" "$_src_dir"
    python3 "$_main_repo/utils/downloads.py" unpack -i "$_main_repo/deps.ini" -c "$_download_cache" "$_src_dir"
fi

if $retrieve_toolchain; then
  pushd "$_src_dir"
    "$_src_dir/tools/rust/update_rust.py"
    for pkg in clang objdump clang-tidy libclang; do
      "$_src_dir/tools/clang/scripts/update.py" --package $pkg;
    done
    "$_src_dir/third_party/node/update_node_binaries"

    NODE="$_src_dir/third_party/node"
    mkdir -p "$NODE/mac_arm64"
    mv "$NODE/mac/node-darwin-arm64" "$NODE/mac_arm64/"
  popd
fi
