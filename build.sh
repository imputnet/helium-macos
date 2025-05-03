#!/usr/bin/env bash

set -eux

# Build script for local macOS environment
_root_dir=$(dirname $(greadlink -f $0))

source "$_root_dir/env.sh"

# Clone to get the Chromium Source
clone=true
while getopts 'd' OPTION; do
  case "$OPTION" in
    d)
      clone=false
      ;;
  esac
done

shift "$(($OPTIND -1))"

_arch=${1:-arm64}

# Add local clang and build tools to PATH
# export PATH="$PATH:$_src_dir/third_party/llvm-build/Release+Asserts/bin"

rm -rf "$_src_dir/out" || true
mkdir -p "$_download_cache"

if $clone; then
  "$_root_dir/retrieve_and_unpack_resource.sh" -g $_arch
else
  "$_root_dir/retrieve_and_unpack_resource.sh" -d -g $_arch
fi

mkdir -p "$_src_dir/out/Default"

# Apply patches and substitutions
python3 "$_main_repo/utils/prune_binaries.py" "$_src_dir" "$_main_repo/pruning.list"
python3 "$_main_repo/utils/patches.py" apply "$_src_dir" "$_main_repo/patches" "$_root_dir/patches"
python3 "$_main_repo/utils/domain_substitution.py" apply -r "$_main_repo/domain_regex.list" -f "$_main_repo/domain_substitution.list" "$_src_dir"
"$_main_repo/utils/name_substitution.sh" sub "$_src_dir"

python3 "$_main_repo/utils/helium_version.py" \
    --tree "$_main_repo" \
    --platform-tree "$_root_dir" \
    --chromium-tree "$_src_dir"

# Generate and apply Helium resources
"$_root_dir/resources/generate_icons.sh"
python3 "$_main_repo/utils/replace_resources.py" "$_root_dir/resources/platform_resources.txt" "$_root_dir/resources" "$_src_dir"
python3 "$_main_repo/utils/replace_resources.py" "$_main_repo/resources/helium_resources.txt" "$_main_repo/resources" "$_src_dir"

# Set build flags
cat "$_main_repo/flags.gn" "$_root_dir/flags.macos.gn" > "$_src_dir/out/Default/args.gn"

if command -v ccache 2>&1 >/dev/null; then
  echo 'cc_wrapper="env CCACHE_SLOPPINESS=time_macros ccache"' >> "$_src_dir/out/Default/args.gn";
else
  echo 'warn: ccache is not available' >&2
fi

# Set target_cpu to the corresponding architecture
if [[ $_arch == "arm64" ]]; then
  echo 'target_cpu = "arm64"' >> "$_src_dir/out/Default/args.gn"
else
  echo 'target_cpu = "x64"' >> "$_src_dir/out/Default/args.gn"
fi

mkdir -p "$_src_dir/third_party/llvm-build/Release+Asserts"
mkdir -p "$_src_dir/third_party/rust-toolchain/bin"

"$_root_dir/retrieve_and_unpack_resource.sh" -p $_arch

cd "$_src_dir"

./tools/gn/bootstrap/bootstrap.py -o out/Default/gn --skip-generate-buildfiles
./tools/rust/build_bindgen.py

./out/Default/gn gen out/Default --fail-on-unused-args

ln -s "$_src_dir/third_party" "$_src_dir/../third_party"

ninja -C out/Default chrome chromedriver

"$_root_dir/sign_and_package_app.sh"
