#!/bin/bash -eux

# Simple script for getting ready to build Helium macOS binaries on GitHub Actions

_target_cpu="$1"

# Some path variables
_root_dir="$(dirname "$(greadlink -f "$0")")"
_download_cache="$_root_dir/build/download_cache"
_src_dir="$_root_dir/build/src"
_main_repo="$_root_dir/helium-chromium"

shopt -s nocasematch

if [[ $_target_cpu == "arm64" ]]; then
  echo 'target_cpu = "arm64"' >> "$_root_dir/flags.macos.gn"
else
  echo 'target_cpu = "x64"' >> "$_root_dir/flags.macos.gn"
fi

cp "$_main_repo/flags.gn" "$_src_dir/out/Default/args.gn"
cat "$_root_dir/flags.macos.gn" >> "$_src_dir/out/Default/args.gn"
echo 'cc_wrapper="sccache"' >> "$_src_dir/out/Default/args.gn"

if ! [ -z "${PROD_MACOS_SPARKLE_ED_PUB_KEY-}" ]; then
  echo 'enable_sparkle=true' >> "$_src_dir/out/Default/args.gn"
  echo 'sparkle_ed_key="'"$PROD_MACOS_SPARKLE_ED_PUB_KEY"'"' >> "$_src_dir/out/Default/args.gn"
fi

echo 'symbol_level=1' >> "$_src_dir/out/Default/args.gn"
echo 'chrome_pgo_phase=2' >> "$_src_dir/out/Default/args.gn"

cd "$_src_dir"

./tools/gn/bootstrap/bootstrap.py -o out/Default/gn --skip-generate-buildfiles
./tools/rust/build_bindgen.py --skip-test

./out/Default/gn gen out/Default --fail-on-unused-args
