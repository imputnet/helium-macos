#!/bin/bash -eux

# Simple script for downloading and unpacking required resources to build Helium macOS binaries on GitHub Actions

_target_cpu="$1"

_root_dir="$(dirname "$(greadlink -f "$0")")"
_download_cache="$_root_dir/build/download_cache"
_src_dir="$_root_dir/build/src"
_main_repo="$_root_dir/helium-chromium"

mkdir -p "$_src_dir"
sudo df -h
sudo du -hs "$_src_dir"

rm -rf "$_src_dir/out" || true
mkdir -p "$_download_cache"

"$_root_dir/retrieve_and_unpack_resource.sh" -g "$_target_cpu"

mkdir -p "$_src_dir/out/Default"

python3 "$_main_repo/utils/prune_binaries.py" "$_src_dir" "$_main_repo/pruning.list"
"$_root_dir/retrieve_and_unpack_resource.sh" -t

python3 "$_main_repo/utils/patches.py" apply "$_src_dir" "$_main_repo/patches" "$_root_dir/patches"
python3 "$_main_repo/utils/domain_substitution.py" apply -r "$_main_repo/domain_regex.list" -f "$_main_repo/domain_substitution.list" "$_src_dir"
python3 "$_main_repo/utils/name_substitution.py" --sub -t "$_src_dir"

python3 "$_main_repo/utils/helium_version.py" \
    --tree "$_main_repo" \
    --platform-tree "$_root_dir" \
    --chromium-tree "$_src_dir"

python3 "$_main_repo/utils/generate_resources.py" "$_main_repo/resources/generate_resources.txt" "$_main_repo/resources"
python3 "$_main_repo/utils/replace_resources.py" "$_root_dir/resources/platform_resources.txt" "$_root_dir/resources" "$_src_dir"
python3 "$_main_repo/utils/replace_resources.py" "$_main_repo/resources/helium_resources.txt" "$_main_repo/resources" "$_src_dir"

rm -rvf "$_download_cache"
